module Geo
  class UploadDeletedEventStore < EventStore
    self.event_type = :upload_deleted_event

    attr_reader :upload

    def initialize(upload)
      @upload = upload
    end

    private

    def build_event
      Geo::UploadDeletedEvent.new(
        upload: upload,
        path: upload.path,
        checksum: upload.checksum,
        model_id: upload.model_id,
        model_type: upload.model_type
      )
    end

    # This is called by ProjectLogHelpers to build json log with context info
    #
    # @see ::Gitlab::Geo::ProjectLogHelpers
    def base_log_data(message)
      {
        class: self.class.name,
        upload_id: upload.id,
        path: upload.path,
        model_id: upload.model_id,
        model_type: upload.model_type,
        message: message
      }
    end
  end
end
