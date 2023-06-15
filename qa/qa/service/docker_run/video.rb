# frozen_string_literal: true

module QA
  module Service
    module DockerRun
      class Video < Base
        class << self
          include Service::Shellout

          PHONE_VIDEO_SIZE = '500x900'
          TABLET_VIDEO_SIZE = '800x1100'
          DESKTOP_VIDEO_SIZE = '1920x1080'

          def configure!
            return unless QA::Runtime::Env.record_video?

            begin
              QA::Runtime::Env.require_video_variables!
            rescue ArgumentError => e
              return QA::Runtime::Logger.warn("Aborting video recording setup! Missing variables: #{e}")
            end

            @recorder_container_name = get_container_name(QA::Runtime::Env.video_recorder_image)
            @browser_image_version =
              "#{QA::Runtime::Env.selenoid_browser_image}:#{QA::Runtime::Env.selenoid_browser_version}"
            @recorder_container_cmd = "docker exec -d #{@recorder_container_name} sh -c".freeze
            set_browser_container_hostname
            set_video_screen_size

            if @recorder_container_name.present? && @browser_container_hostname
              configure_rspec

              QA::Runtime::Logger.info("Test failure video recording setup complete!")
            else
              QA::Runtime::Logger.warn("Test failure video recording setup failed!")
            end
          end

          def start_recording(example)
            @current_recording_name = create_recording_name(example)

            ffmpeg_cmd = <<~CMD.tr("\n", ' ')
              ffmpeg -y
              -f x11grab
              -video_size #{@video_size}
              -r 15
              -i #{@browser_container_hostname}:99
              -vcodec 'libx264'
              -pix_fmt 'yuv420p'
              "/data/#{@current_recording_name}.mp4"
            CMD

            begin
              shell("#{@recorder_container_cmd} '#{ffmpeg_cmd}'")
            rescue StandardError => e
              QA::Runtime::Logger.warn("Video recording start error: #{e}")
            end
          end

          def stop_recording
            shell("#{@recorder_container_cmd} 'pkill -INT -f ffmpeg'")
          rescue StandardError => e
            QA::Runtime::Logger.warn("Video recording stop error: #{e}")
          end

          def delete_video
            shell("#{@recorder_container_cmd} 'rm /data/#{@current_recording_name}.mp4'")
          rescue StandardError => e
            QA::Runtime::Logger.warn("Video deletion error: #{e}")
          end

          private

          def configure_rspec
            RSpec.configure do |config|
              config.prepend_before do |example|
                QA::Service::DockerRun::Video.start_recording(example)
              end

              config.append_after do |example|
                QA::Service::DockerRun::Video.stop_recording
                QA::Service::DockerRun::Video.delete_video unless example.exception
              end
            end
          end

          def create_recording_name(example)
            test_name = example.full_description.downcase.parameterize(separator: "_")[0..56]
            test_time = Time.now.strftime "%Y-%m-%d-%H-%M-%S-%L"

            "#{test_name}-#{test_time}"
          end

          def get_container_name(image)
            name = shell("docker ps -f ancestor='#{image}' --format '{{.Names}}'")

            QA::Runtime::Logger.warn("Getting container name for #{image} failed!") if name.empty?

            name
          end

          def set_browser_container_hostname
            container_name = get_container_name(@browser_image_version)
            @browser_container_hostname = shell("docker inspect #{container_name} --format '{{.Config.Hostname}}'")
          rescue StandardError => e
            QA::Runtime::Logger.warn("Video recording browser container setup error: #{e}")
          end

          def set_video_screen_size
            @video_size =
              if QA::Runtime::Env.phone_layout?
                PHONE_VIDEO_SIZE
              elsif QA::Runtime::Env.tablet_layout?
                TABLET_VIDEO_SIZE
              else
                DESKTOP_VIDEO_SIZE
              end
          end
        end
      end
    end
  end
end
