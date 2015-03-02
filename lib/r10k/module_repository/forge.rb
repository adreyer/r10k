require 'r10k/module_repository'
require 'r10k/version'

require 'faraday'
require 'faraday_middleware/multi_json'
require 'faraday_middleware'

class R10K::ModuleRepository::Forge

  # @!attribute [r] forge
  #   @return [String] The forge hostname to use for requests
  attr_reader :forge

  # @!attribute [r] :conn
  #   @api private
  #   @return [Faraday]
  attr_reader :conn

  def initialize(forge = 'forgeapi.puppetlabs.com')
    if forge =~ /forge\.puppetlabs\.com/
      logger.warn("#{forge} does not support the latest puppet forge API. Please update to \"forge 'https://forgeapi.puppetlabs.com'\"")
      forge = 'forgeapi.puppetlabs.com'
    end
    @forge = forge

    @conn = Faraday.new(
      :url => "https://#{@forge}",
      :user_agent => "Ruby/r10k #{R10K::VERSION}"
    ) do |builder|
      builder.request :multi_json
      builder.response :multi_json

      # This needs to be _after_ request/response configuration for testing
      # purposes. This comment is the result of much consternation.
      builder.adapter Faraday.default_adapter
    end
  end

  # Query for all published versions of a module
  #
  # @example
  #   forge = R10K::ModuleRepository::Forge.new
  #   forge.versions('adrien/boolean')
  #   #=> ["0.9.0-rc1", "0.9.0", "1.0.0", "1.0.1"]
  #
  # @param module_name [String] The fully qualified module name
  # @return [Array<String>] All published versions of the given module
  def versions(module_name)
    response = @conn.get("/v3/modules/#{module_name.tr('/','-')}")

    if response.status != 200
      raise "couldn't get #{module_name} from forge at /v3/modules/#{module_name.tr('/','-')}."
    end

    response.body['releases'].map do |version_info|
      version_info['version']
    end.reverse
  end

  # Query for the newest published version of a module
  #
  # @example
  #   forge = R10K::ModuleRepository::Forge.new
  #   forge.latest_version('adrien/boolean')
  #   #=> "1.0.1"
  #
  # @param module_name [String] The fully qualified module name
  # @return [String] The latest published version of the given module
  def latest_version(module_name)
    versions(module_name).last
  end
end
