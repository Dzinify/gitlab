module BlobViewer
  class DependencyManager < Base
    include Auxiliary

    self.partial_name = 'dependency_manager'
    self.binary = false

    def manager_name
      raise NotImplementedError
    end

    def manager_url
      raise NotImplementedError
    end

    def package_type
      'package'
    end

    def package_name
      nil
    end

    def package_url
      nil
    end

    private

    def package_name_from_json(key)
      prepare!

      JSON.parse(blob.data)[key] rescue nil
    end

    def package_name_from_method_call(name)
      prepare!

      match = blob.data.match(/#{name}\s*=\s*["'](?<name>[^"']+)["']/)
      match[:name] if match
    end
  end
end
