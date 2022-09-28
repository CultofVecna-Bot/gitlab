# frozen_string_literal: true

module BoardsActions
  include Gitlab::Utils::StrongMemoize
  extend ActiveSupport::Concern

  included do
    include BoardsResponses

    before_action :authorize_read_board!, only: [:index, :show]
    before_action :redirect_to_recent_board, only: [:index]
    before_action :board, only: [:index, :show]
    before_action :push_licensed_features, only: [:index, :show]
  end

  def index
    # if no board exists, create one
    @board = board_create_service.execute.payload unless board # rubocop:disable Gitlab/ModuleWithInstanceVariables
  end

  def show
    return render_404 unless board

    # Add / update the board in the recent visits table
    board_visit_service.new(parent, current_user).execute(board)
  end

  private

  def redirect_to_recent_board
    return if !parent.multiple_issue_boards_available? || !latest_visited_board

    redirect_to board_path(latest_visited_board.board)
  end

  def latest_visited_board
    @latest_visited_board ||= Boards::VisitsFinder.new(parent, current_user).latest
  end

  # Noop on FOSS
  def push_licensed_features
  end

  def board
    strong_memoize(:board) do
      board_finder.execute.first
    end
  end

  def board_visit_service
    Boards::Visits::CreateService
  end
end

BoardsActions.prepend_mod_with('BoardsActions')
