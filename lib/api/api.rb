# frozen_string_literal: true

module API
  class API < ::API::Base
    include APIGuard
    include Helpers::OpenApi

    LOG_FILENAME = Rails.root.join("log", "api_json.log")

    NO_SLASH_URL_PART_REGEX = %r{[^/]+}.freeze
    NAMESPACE_OR_PROJECT_REQUIREMENTS = { id: NO_SLASH_URL_PART_REGEX }.freeze
    COMMIT_ENDPOINT_REQUIREMENTS = NAMESPACE_OR_PROJECT_REQUIREMENTS.merge(sha: NO_SLASH_URL_PART_REGEX).freeze
    USER_REQUIREMENTS = { user_id: NO_SLASH_URL_PART_REGEX }.freeze
    LOG_FILTERS = ::Rails.application.config.filter_parameters + [/^output$/]
    LOG_FORMATTER = Gitlab::GrapeLogging::Formatters::LogrageWithTimestamp.new
    LOGGER = Logger.new(LOG_FILENAME)

    insert_before Grape::Middleware::Error,
                  GrapeLogging::Middleware::RequestLogger,
                  logger: LOGGER,
                  formatter: LOG_FORMATTER,
                  include: [
                    Gitlab::GrapeLogging::Loggers::FilterParameters.new(LOG_FILTERS),
                    Gitlab::GrapeLogging::Loggers::ClientEnvLogger.new,
                    Gitlab::GrapeLogging::Loggers::RouteLogger.new,
                    Gitlab::GrapeLogging::Loggers::UserLogger.new,
                    Gitlab::GrapeLogging::Loggers::TokenLogger.new,
                    Gitlab::GrapeLogging::Loggers::ExceptionLogger.new,
                    Gitlab::GrapeLogging::Loggers::QueueDurationLogger.new,
                    Gitlab::GrapeLogging::Loggers::PerfLogger.new,
                    Gitlab::GrapeLogging::Loggers::CorrelationIdLogger.new,
                    Gitlab::GrapeLogging::Loggers::ContextLogger.new,
                    Gitlab::GrapeLogging::Loggers::ContentLogger.new,
                    Gitlab::GrapeLogging::Loggers::UrgencyLogger.new,
                    Gitlab::GrapeLogging::Loggers::ResponseLogger.new
                  ]

    allow_access_with_scope :api
    allow_access_with_scope :read_api, if: -> (request) { request.get? || request.head? }
    prefix :api

    version 'v3', using: :path do
      route :any, '*path' do
        error!('API V3 is no longer supported. Use API V4 instead.', 410)
      end
    end

    version 'v4', using: :path

    before do
      header['X-Frame-Options'] = 'SAMEORIGIN'
      header['X-Content-Type-Options'] = 'nosniff'

      if Rails.application.config.content_security_policy && !Rails.application.config.content_security_policy_report_only
        policy = ActionDispatch::ContentSecurityPolicy.new { |p| p.default_src :none }
      end

      request.env[ActionDispatch::ContentSecurityPolicy::Request::POLICY] = policy
    end

    before do
      coerce_nil_params_to_array!

      api_endpoint = request.env[Grape::Env::API_ENDPOINT]
      feature_category = api_endpoint.options[:for].try(:feature_category_for_app, api_endpoint).to_s

      # remote_ip is added here and the ContextLogger so that the
      # client_id field is set correctly, as the user object does not
      # survive between multiple context pushes.
      Gitlab::ApplicationContext.push(
        user: -> { @current_user },
        project: -> { @project },
        namespace: -> { @group },
        runner: -> { @current_runner || @runner },
        remote_ip: request.ip,
        caller_id: api_endpoint.endpoint_id,
        feature_category: feature_category
      )
    end

    before do
      set_peek_enabled_for_current_request
    end

    after do
      Gitlab::UsageDataCounters::VSCodeExtensionActivityUniqueCounter.track_api_request_when_trackable(user_agent: request&.user_agent, user: @current_user)
    end

    after do
      Gitlab::UsageDataCounters::JetBrainsPluginActivityUniqueCounter.track_api_request_when_trackable(user_agent: request&.user_agent, user: @current_user)
    end

    after do
      Gitlab::UsageDataCounters::GitLabCliActivityUniqueCounter.track_api_request_when_trackable(user_agent: request&.user_agent, user: @current_user)
    end

    # The locale is set to the current user's locale when `current_user` is loaded
    after { Gitlab::I18n.use_default_locale }

    rescue_from Gitlab::Access::AccessDeniedError do
      rack_response({ 'message' => '403 Forbidden' }.to_json, 403)
    end

    rescue_from ActiveRecord::RecordNotFound do
      rack_response({ 'message' => '404 Not found' }.to_json, 404)
    end

    rescue_from(
      ::ActiveRecord::StaleObjectError,
      ::Gitlab::ExclusiveLeaseHelpers::FailedToObtainLockError
    ) do
      rack_response({ 'message' => '409 Conflict: Resource lock' }.to_json, 409)
    end

    rescue_from UploadedFile::InvalidPathError do |e|
      rack_response({ 'message' => e.message }.to_json, 400)
    end

    rescue_from ObjectStorage::RemoteStoreError do |e|
      rack_response({ 'message' => e.message }.to_json, 500)
    end

    # Retain 405 error rather than a 500 error for Grape 0.15.0+.
    # https://github.com/ruby-grape/grape/blob/a3a28f5b5dfbb2797442e006dbffd750b27f2a76/UPGRADING.md#changes-to-method-not-allowed-routes
    rescue_from Grape::Exceptions::MethodNotAllowed do |e|
      error! e.message, e.status, e.headers
    end

    rescue_from Grape::Exceptions::Base do |e|
      error! e.message, e.status, e.headers
    end

    rescue_from Gitlab::Auth::TooManyIps do |e|
      rack_response({ 'message' => '403 Forbidden' }.to_json, 403)
    end

    rescue_from :all do |exception|
      handle_api_exception(exception)
    end

    # This is a specific exception raised by `rack-timeout` gem when Puma
    # requests surpass its timeout. Given it inherits from Exception, we
    # should rescue it separately. For more info, see:
    # - https://github.com/zombocom/rack-timeout/blob/master/doc/exceptions.md
    # - https://github.com/ruby-grape/grape#exception-handling
    rescue_from Rack::Timeout::RequestTimeoutException do |exception|
      handle_api_exception(exception)
    end

    rescue_from RateLimitedService::RateLimitedError do |exception|
      exception.log_request(context.request, context.current_user)
      rack_response({ 'message' => { 'error' => exception.message } }.to_json, 429, exception.headers)
    end

    format :json
    formatter :json, Gitlab::Json::GrapeFormatter
    content_type :json, 'application/json'

    # Ensure the namespace is right, otherwise we might load Grape::API::Helpers
    helpers ::API::Helpers
    helpers ::API::Helpers::CommonHelpers
    helpers ::API::Helpers::PerformanceBarHelpers
    helpers ::API::Helpers::RateLimiter

    namespace do
      after do
        ::Users::ActivityService.new(@current_user).execute
      end

      # Mount endpoints to include in the OpenAPI V2 documentation here
      namespace do
        # Keep in alphabetical order
        mount ::API::AccessRequests
        mount ::API::Appearance
        mount ::API::BulkImports
        mount ::API::Ci::Runner
        mount ::API::Ci::Runners
        mount ::API::Clusters::Agents
        mount ::API::Clusters::AgentTokens
        mount ::API::DeployKeys
        mount ::API::DeployTokens
        mount ::API::Deployments
        mount ::API::Environments
        mount ::API::FeatureFlagsUserLists
        mount ::API::FeatureFlags
        mount ::API::Features
        mount ::API::FreezePeriods
        mount ::API::Keys
        mount ::API::Metadata
        mount ::API::MergeRequestDiffs
        mount ::API::ProjectRepositoryStorageMoves
        mount ::API::Releases
        mount ::API::Release::Links
        mount ::API::ResourceAccessTokens
        mount ::API::ProtectedTags
        mount ::API::SnippetRepositoryStorageMoves
        mount ::API::ProtectedBranches
        mount ::API::Statistics
        mount ::API::Submodules
        mount ::API::Suggestions
        mount ::API::Tags
        mount ::API::UserCounts

        add_open_api_documentation!
      end

      # Keep in alphabetical order
      mount ::API::Admin::BatchedBackgroundMigrations
      mount ::API::Admin::Ci::Variables
      mount ::API::Admin::InstanceClusters
      mount ::API::Admin::PlanLimits
      mount ::API::Admin::Sidekiq
      mount ::API::AlertManagementAlerts
      mount ::API::Applications
      mount ::API::Avatar
      mount ::API::AwardEmoji
      mount ::API::Badges
      mount ::API::Boards
      mount ::API::Branches
      mount ::API::BroadcastMessages
      mount ::API::Ci::JobArtifacts
      mount ::API::Ci::Jobs
      mount ::API::Ci::PipelineSchedules
      mount ::API::Ci::Pipelines
      mount ::API::Ci::ResourceGroups
      mount ::API::Ci::SecureFiles
      mount ::API::Ci::Triggers
      mount ::API::Ci::Variables
      mount ::API::CommitStatuses
      mount ::API::Commits
      mount ::API::ComposerPackages
      mount ::API::ConanInstancePackages
      mount ::API::ConanProjectPackages
      mount ::API::ContainerRegistryEvent
      mount ::API::ContainerRepositories
      mount ::API::DebianGroupPackages
      mount ::API::DebianProjectPackages
      mount ::API::DependencyProxy
      mount ::API::Discussions
      mount ::API::ErrorTracking::ClientKeys
      mount ::API::ErrorTracking::Collector
      mount ::API::ErrorTracking::ProjectSettings
      mount ::API::Events
      mount ::API::Files
      mount ::API::GenericPackages
      mount ::API::Geo
      mount ::API::GoProxy
      mount ::API::GroupAvatar
      mount ::API::GroupBoards
      mount ::API::GroupClusters
      mount ::API::GroupContainerRepositories
      mount ::API::GroupDebianDistributions
      mount ::API::GroupExport
      mount ::API::GroupImport
      mount ::API::GroupLabels
      mount ::API::GroupMilestones
      mount ::API::GroupPackages
      mount ::API::GroupVariables
      mount ::API::Groups
      mount ::API::HelmPackages
      mount ::API::ImportBitbucketServer
      mount ::API::ImportGithub
      mount ::API::Integrations
      mount ::API::Integrations::JiraConnect::Subscriptions
      mount ::API::Invitations
      mount ::API::IssueLinks
      mount ::API::Issues
      mount ::API::Labels
      mount ::API::Lint
      mount ::API::Markdown
      mount ::API::MavenPackages
      mount ::API::Members
      mount ::API::MergeRequestApprovals
      mount ::API::MergeRequests
      mount ::API::Metrics::Dashboard::Annotations
      mount ::API::Metrics::UserStarredDashboards
      mount ::API::Namespaces
      mount ::API::Notes
      mount ::API::NotificationSettings
      mount ::API::NpmInstancePackages
      mount ::API::NpmProjectPackages
      mount ::API::NugetGroupPackages
      mount ::API::NugetProjectPackages
      mount ::API::PackageFiles
      mount ::API::Pages
      mount ::API::PagesDomains
      mount ::API::PersonalAccessTokens::SelfInformation
      mount ::API::PersonalAccessTokens
      mount ::API::ProjectClusters
      mount ::API::ProjectContainerRepositories
      mount ::API::ProjectDebianDistributions
      mount ::API::ProjectEvents
      mount ::API::ProjectExport
      mount ::API::ProjectHooks
      mount ::API::ProjectImport
      mount ::API::ProjectMilestones
      mount ::API::ProjectPackages
      mount ::API::ProjectSnapshots
      mount ::API::ProjectSnippets
      mount ::API::ProjectStatistics
      mount ::API::ProjectTemplates
      mount ::API::Projects
      mount ::API::ProtectedTags
      mount ::API::PypiPackages
      mount ::API::RemoteMirrors
      mount ::API::Repositories
      mount ::API::ResourceLabelEvents
      mount ::API::ResourceMilestoneEvents
      mount ::API::ResourceStateEvents
      mount ::API::RpmProjectPackages
      mount ::API::RubygemPackages
      mount ::API::Search
      mount ::API::Settings
      mount ::API::SidekiqMetrics
      mount ::API::Snippets
      mount ::API::Subscriptions
      mount ::API::SystemHooks
      mount ::API::Tags
      mount ::API::Templates
      mount ::API::Terraform::Modules::V1::Packages
      mount ::API::Terraform::State
      mount ::API::Terraform::StateVersion
      mount ::API::Todos
      mount ::API::Topics
      mount ::API::Unleash
      mount ::API::UsageData
      mount ::API::UsageDataNonSqlMetrics
      mount ::API::UsageDataQueries
      mount ::API::Users
      mount ::API::Wikis
      mount ::API::Ml::Mlflow
    end

    mount ::API::Internal::Base
    mount ::API::Internal::Lfs
    mount ::API::Internal::Pages
    mount ::API::Internal::Kubernetes
    mount ::API::Internal::ErrorTracking
    mount ::API::Internal::MailRoom
    mount ::API::Internal::ContainerRegistry::Migration
    mount ::API::Internal::Workhorse

    version 'v3', using: :path do
      # Although the following endpoints are kept behind V3 namespace,
      # they're not deprecated neither should be removed when V3 get
      # removed.  They're needed as a layer to integrate with Jira
      # Development Panel.
      namespace '/', requirements: ::API::V3::Github::ENDPOINT_REQUIREMENTS do
        mount ::API::V3::Github
      end
    end

    route :any, '*path', feature_category: :not_owned do # rubocop:todo Gitlab/AvoidFeatureCategoryNotOwned
      error!('404 Not Found', 404)
    end
  end
end

API::API.prepend_mod
