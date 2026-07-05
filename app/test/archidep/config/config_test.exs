defmodule ArchiDep.ConfigTest do
  use ExUnit.Case, async: true

  alias ArchiDep.Config
  alias ArchiDep.Config.ConfigError

  describe "auth/2" do
    test "reads the root users from the environment as a comma-separated list" do
      env = %{"ARCHIDEP_AUTH_SWITCH_EDU_ID_ROOT_USERS" => "a@archidep.ch, b@archidep.ch"}
      default_config = [root_users: [switch_edu_id: ["ignored@archidep.ch"]]]

      assert Config.auth(env, default_config) == [
               root_users: [switch_edu_id: ["a@archidep.ch", "b@archidep.ch"]]
             ]
    end

    test "falls back to the application configuration when the environment is unset" do
      default_config = [root_users: [switch_edu_id: ["a@archidep.ch", "b@archidep.ch"]]]

      assert Config.auth(%{}, default_config) == [
               root_users: [switch_edu_id: ["a@archidep.ch", "b@archidep.ch"]]
             ]
    end

    test "raises when a comma-separated list from the environment contains a blank entry" do
      env = %{"ARCHIDEP_AUTH_SWITCH_EDU_ID_ROOT_USERS" => "a@archidep.ch,,b@archidep.ch"}

      assert_raise ConfigError,
                   "Application root users \"a@archidep.ch,,b@archidep.ch\" is invalid.\n" <>
                     "It must be a comma-separated list of emails or swissEduPersonUniqueID of switch edu-ID users.\n" <>
                     "This value was set in environment variable $ARCHIDEP_AUTH_SWITCH_EDU_ID_ROOT_USERS.",
                   fn -> Config.auth(env, root_users: [switch_edu_id: ["a@archidep.ch"]]) end
    end

    test "raises when the configured list contains a blank entry" do
      default_config = [root_users: [switch_edu_id: [""]]]

      assert_raise ConfigError,
                   "Application root users [\"\"] is invalid.\n" <>
                     "It must be a comma-separated list of emails or swissEduPersonUniqueID of switch edu-ID users.\n" <>
                     "This value was set in one of the \"config/*.exs\" files.",
                   fn -> Config.auth(%{}, default_config) end
    end

    test "raises when the root users are neither in the environment nor the configuration" do
      assert_raise ConfigError,
                   "Application root users is required but was not provided.\n" <>
                     "It must be a comma-separated list of emails or swissEduPersonUniqueID of switch edu-ID users.\n\n" <>
                     "Set it with environment variable $ARCHIDEP_AUTH_SWITCH_EDU_ID_ROOT_USERS.\n" <>
                     "Or set it with one of the \"config/*.exs\" files.",
                   fn -> Config.auth(%{}, root_users: [switch_edu_id: nil]) end
    end

    test "raises when the configured list is empty" do
      assert_raise ConfigError,
                   "Application root users is required but was not provided.\n" <>
                     "It must be a comma-separated list of emails or swissEduPersonUniqueID of switch edu-ID users.\n\n" <>
                     "Set it with environment variable $ARCHIDEP_AUTH_SWITCH_EDU_ID_ROOT_USERS.\n" <>
                     "Or set it with one of the \"config/*.exs\" files.",
                   fn -> Config.auth(%{}, root_users: [switch_edu_id: []]) end
    end
  end

  describe "sentry/2" do
    test "reads the DSN from the environment" do
      env = %{"ARCHIDEP_SENTRY_DSN" => "https://public@sentry.example.com/1"}

      assert Config.sentry(env, dsn: "ignored") == [
               dsn: "https://public@sentry.example.com/1"
             ]
    end

    test "falls back to the application configuration when the environment is unset" do
      assert Config.sentry(%{}, dsn: "https://public@sentry.example.com/1") == [
               dsn: "https://public@sentry.example.com/1"
             ]
    end

    test "returns a nil DSN when neither the environment nor the configuration set it" do
      assert Config.sentry(%{}, []) == [dsn: nil]
    end
  end

  describe "servers/2" do
    @describetag :tmp_dir
    setup %{tmp_dir: tmp_dir} do
      ssh_private_key_file = create_key_file(tmp_dir, "default", "id_ed25519", 0o600)

      %{
        default_config: [
          api_base_url: "https://archidep.ch/api",
          ssh_private_key_file: ssh_private_key_file,
          ssh_public_key: "ssh-ed25519 AAAAC3Nz"
        ],
        ssh_private_key_file: ssh_private_key_file
      }
    end

    test "reads the whole server configuration from the environment", %{
      default_config: default_config,
      tmp_dir: tmp_dir
    } do
      env_key_file = create_key_file(tmp_dir, "env", "id_rsa", 0o600)

      env = %{
        "ARCHIDEP_SERVERS_API_BASE_URL" => "https://other.example.com/api",
        "ARCHIDEP_SERVERS_SSH_PRIVATE_KEY_FILE" => env_key_file,
        "ARCHIDEP_SERVERS_SSH_PUBLIC_KEY" => "ssh-rsa BBBBB"
      }

      assert Config.servers(env, default_config) == [
               api_base_url: "https://other.example.com/api",
               ssh_private_key_file: env_key_file,
               ssh_public_key: "ssh-rsa BBBBB"
             ]
    end

    test "falls back to the application configuration when the environment is unset", %{
      default_config: default_config,
      ssh_private_key_file: ssh_private_key_file
    } do
      assert Config.servers(%{}, default_config) == [
               api_base_url: "https://archidep.ch/api",
               ssh_private_key_file: ssh_private_key_file,
               ssh_public_key: "ssh-ed25519 AAAAC3Nz"
             ]
    end

    test "accepts either an http or https base URL", %{
      default_config: default_config,
      ssh_private_key_file: ssh_private_key_file
    } do
      for url <- ["https://archidep.ch/api", "http://localhost:4000/api"] do
        assert Config.servers(%{}, Keyword.put(default_config, :api_base_url, url)) == [
                 api_base_url: url,
                 ssh_private_key_file: ssh_private_key_file,
                 ssh_public_key: "ssh-ed25519 AAAAC3Nz"
               ]
      end
    end

    test "rejects a base URL that is not a valid http(s) URL with a path", %{
      default_config: default_config
    } do
      for bad_url <- ["https://archidep.ch/", "ftp://archidep.ch/api", "archidep.ch/api"] do
        assert_raise ConfigError,
                     "API base URL #{inspect(bad_url)} is invalid.\n" <>
                       "It must be the base URL of the ArchiDep API, e.g. \"https://archidep.ch/api\".\n" <>
                       "This value was set in one of the \"config/*.exs\" files.",
                     fn ->
                       Config.servers(%{}, Keyword.put(default_config, :api_base_url, bad_url))
                     end
      end
    end

    test "raises when the SSH public key is missing", %{default_config: default_config} do
      assert_raise ConfigError,
                   "SSH public key is required but was not provided.\n" <>
                     "It must be an SSH public key.\n\n" <>
                     "Set it with environment variable $ARCHIDEP_SERVERS_SSH_PUBLIC_KEY.\n" <>
                     "Or set it with one of the \"config/*.exs\" files.",
                   fn ->
                     Config.servers(%{}, Keyword.put(default_config, :ssh_public_key, nil))
                   end
    end

    test "rejects an SSH private key file that is invalid, explaining why", %{
      default_config: default_config,
      tmp_dir: tmp_dir
    } do
      permissive = create_key_file(tmp_dir, "permissive", "id_ed25519", 0o644)
      write_only = create_key_file(tmp_dir, "write_only", "id_ed25519", 0o200)
      unsupported = create_key_file(tmp_dir, "unsupported", "id_dsa", 0o600)
      not_a_file = Path.join([tmp_dir, "dir", "id_ed25519"])
      File.mkdir_p!(not_a_file)
      missing = Path.join(tmp_dir, "does_not_exist_id_ed25519")

      cases = [
        {permissive, "the file must not be accessible by group or others"},
        {write_only, "the file is not readable"},
        {unsupported,
         ~s(the file name is not a standard SSH private key name such as "id_ed25519")},
        {not_a_file, "the path is not a regular file"},
        {missing, "the file could not be read (no such file or directory)"}
      ]

      for {path, reason} <- cases do
        assert_raise ConfigError,
                     "SSH private key file #{inspect(path)} is invalid: #{reason}\n" <>
                       "It must be the path to a readable file containing an SSH private key. The file must have a standard name (e.g. \"id_ed25519\").\n" <>
                       "This value was set in one of the \"config/*.exs\" files.",
                     fn ->
                       Config.servers(
                         %{},
                         Keyword.put(default_config, :ssh_private_key_file, path)
                       )
                     end
      end
    end
  end

  describe "repo/2" do
    setup do
      %{
        default_config: [
          pool_size: 5,
          socket_options: [],
          url: "ecto://u:p@db.example.com/archidep"
        ]
      }
    end

    test "reads the whole repository configuration from the environment", %{
      default_config: default_config
    } do
      env = %{
        "ARCHIDEP_REPO_POOL_SIZE" => "20",
        "ARCHIDEP_REPO_IPV6" => "true",
        "ARCHIDEP_REPO_URL" => "ecto://user:pass@other.example.com:5433/other"
      }

      assert Config.repo(env, default_config) == [
               pool_size: 20,
               socket_options: [:inet6],
               url: "ecto://user:pass@other.example.com:5433/other"
             ]
    end

    test "falls back to the application configuration when the environment is unset", %{
      default_config: default_config
    } do
      assert Config.repo(%{}, default_config) == [
               pool_size: 5,
               socket_options: [],
               url: "ecto://u:p@db.example.com/archidep"
             ]
    end

    test "omits the pool size when neither the environment nor the configuration set it" do
      assert Config.repo(%{}, url: "ecto://u:p@db.example.com/archidep") == [
               socket_options: [],
               url: "ecto://u:p@db.example.com/archidep"
             ]
    end

    test "prepends the configured socket options before the IPv6 flag", %{
      default_config: default_config
    } do
      config = Keyword.put(default_config, :socket_options, keepalive: true)

      assert Config.repo(%{"ARCHIDEP_REPO_IPV6" => "true"}, config) == [
               pool_size: 5,
               socket_options: [{:keepalive, true}, :inet6],
               url: "ecto://u:p@db.example.com/archidep"
             ]
    end

    test "parses truthy and falsy IPv6 flags from the environment", %{
      default_config: default_config
    } do
      for {raw, expected} <- [
            {"1", [:inet6]},
            {"y", [:inet6]},
            {"yes", [:inet6]},
            {"t", [:inet6]},
            {"true", [:inet6]},
            {"0", []},
            {"no", []},
            {"false", []}
          ] do
        assert Config.repo(%{"ARCHIDEP_REPO_IPV6" => raw}, default_config) == [
                 pool_size: 5,
                 socket_options: expected,
                 url: "ecto://u:p@db.example.com/archidep"
               ]
      end
    end

    test "raises when the IPv6 flag from the environment is not a boolean", %{
      default_config: default_config
    } do
      assert_raise ConfigError,
                   ~s|Repo IPv6 flag "maybe" is invalid.\n| <>
                     ~s|It must be a boolean, e.g. "true" or "false".\n| <>
                     "This value was set in environment variable $ARCHIDEP_REPO_IPV6.",
                   fn -> Config.repo(%{"ARCHIDEP_REPO_IPV6" => "maybe"}, default_config) end
    end

    test "raises when the pool size from the environment is not an integer", %{
      default_config: default_config
    } do
      assert_raise ConfigError,
                   "Repo pool size \"abc\" is invalid.\n" <>
                     "It must be an integer between 1 and 100.\n" <>
                     "This value was set in environment variable $ARCHIDEP_REPO_POOL_SIZE.",
                   fn -> Config.repo(%{"ARCHIDEP_REPO_POOL_SIZE" => "abc"}, default_config) end
    end

    test "raises when the pool size is out of the 1..100 range", %{default_config: default_config} do
      for raw <- ["0", "101"] do
        assert_raise ConfigError,
                     "Repo pool size #{inspect(raw)} is invalid.\n" <>
                       "It must be an integer between 1 and 100.\n" <>
                       "This value was set in environment variable $ARCHIDEP_REPO_POOL_SIZE.",
                     fn -> Config.repo(%{"ARCHIDEP_REPO_POOL_SIZE" => raw}, default_config) end
      end
    end

    test "raises when the repository URL is not a valid ecto URL", %{
      default_config: default_config
    } do
      for bad_url <- [
            "postgres://u:p@db.example.com/archidep",
            "ecto://db.example.com/",
            "not a url"
          ] do
        assert_raise ConfigError,
                     "Repo URL #{inspect(bad_url)} is invalid.\n" <>
                       "It must be an Ecto database URL with the \"ecto://\" scheme, for example:\n\n" <>
                       "    ecto://<user>:<password>@<host>:<port>/<database>\n" <>
                       "This value was set in one of the \"config/*.exs\" files.",
                     fn -> Config.repo(%{}, Keyword.put(default_config, :url, bad_url)) end
      end
    end

    test "raises when the repository URL is neither in the environment nor the configuration" do
      assert_raise ConfigError,
                   "Repo URL is required but was not provided.\n" <>
                     "It must be an Ecto database URL with the \"ecto://\" scheme, for example:\n\n" <>
                     "    ecto://<user>:<password>@<host>:<port>/<database>\n\n" <>
                     "Set it with environment variable $ARCHIDEP_REPO_URL.\n" <>
                     "Or set it with one of the \"config/*.exs\" files.",
                   fn -> Config.repo(%{}, pool_size: 5, socket_options: []) end
    end
  end

  defp create_key_file(tmp_dir, subdir, name, mode) do
    dir = Path.join(tmp_dir, subdir)
    File.mkdir_p!(dir)
    path = Path.join(dir, name)
    File.write!(path, "key")
    File.chmod!(path, mode)
    path
  end
end
