require "heroku/command"
require "tmpdir"
require "rest_client"

# manage buildpacks
#
class Heroku::Command::Buildpacks < Heroku::Command::Base

  # buildpacks
  #
  # list the buildpacks in your kit
  #
  def index
    styled_header "Buildpacks in #{auth.user}'s kit"
    styled_array json_decode(server["/user/buildpacks"].get)
  end

  # buildpacks:setup
  #
  # set up the BUILDPACK_URL for an app
  #
  def setup
    action "Modifying BUILDPACK_URL for #{app}" do
      buildpack_url = buildkit_host + "/buildkit/#{auth.password}.git"
      api.put_config_vars app, "BUILDPACK_URL" => buildpack_url
    end
  end

  # buildpacks:list
  #
  # list all available buildpacks
  #
  def list
    styled_header "Available buildpacks"
    styled_array json_decode(server["/buildpacks"].get)
  end

  # buildpacks:add NAME
  #
  # add a buildpack to your kit
  #
  def add
    name = shift_argument || error("Must specify a buildpack name")
    action("Adding #{name} to your kit") do
      begin
        server["/user/buildpacks"].post(:name => name)
      rescue RestClient::ResourceNotFound
        error "No such buildpack: #{name}"
      rescue RestClient::Forbidden
        error "The #{name} buildpack is already in your kit"
      end
    end
  end

  # buildpacks:remove NAME
  #
  # remove a buildpack from your kit
  #
  def remove
    name = shift_argument || error("Must specify a buildpack name")
    action("Removing #{name} from your kit") do
      begin
        server["/user/buildpacks/#{name}"].delete
      rescue RestClient::ResourceNotFound
        error "The #{name} buildpack is not in your kit"
      end
    end
  end

  # buildpacks:publish NAME
  #
  # publish a buildpack
  #
  def publish
    name = shift_argument || error("Must specify a buildpack name")

    action "Publishing #{name} buildpack" do
      Dir.mktmpdir do |dir|
        %x{ tar czf #{dir}/buildpack.tgz * }

        begin
          buildpack = File.open("#{dir}/buildpack.tgz", "rb")
          response = server["/buildpacks/#{name}"].post :buildpack => buildpack
          revision = json_decode(response)["revision"]
          puts "Published revision #{revision}"
        rescue RestClient::Forbidden
          error "The name '#{name}' is already taken."
        end
      end
    end
  end

  # buildpacks:rollback NAME
  #
  # roll back a buildpack to previous revision
  #
  def rollback
    name = shift_argument || error("Must specify a buildpack name")
    action "Rolling back #{name} buildpack" do
      begin
        response = server["/buildpacks/#{name}"].delete
        revision = json_decode(response)["revision"]
        puts "Rolled back to revision #{revision}."
      rescue RestClient::Forbidden
        error "The '#{name}' buildpack is owned by someone else."
      rescue RestClient::ResourceNotFound
        error "The '#{name}' buildpack does not exist."
      end
    end
  end

private

  def auth
    Heroku::Auth
  end

  def buildkit_host
    ENV["BUILDPACK_SERVER_URL"] || "https://buildkits.herokuapp.com"
  end

  def server
    RestClient::Resource.new buildkit_host, :user => auth.user, :password => auth.password
  end

end
