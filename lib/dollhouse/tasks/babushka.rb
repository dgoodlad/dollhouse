module Dollhouse
  module Tasks
    module Babushka
      # TODO upload a bootstrap script instead of specifying a url
      DEFAULT_BOOTSTRAP_SCRIPT_URL = "http://j.mp/babushkamehard"

      # Download and run the babushka bootstrap (requires root access)
      def bootstrap_babushka(script_url = nil)
        script_url = DEFAULT_BOOTSTRAP_SCRIPT_URL if script_url.nil?
        exec "wget #{script_url} -O babushka-bootstrap.sh"
        exec "chmod +x babushka-bootstrap.sh"
        exec "headless=true ./babushka-bootstrap.sh"
      end

      def clear_babushka_sources
        exec "babushka sources -c"
      end

      def add_babushka_source(name, uri)
        exec "babushka sources -a #{name} #{uri}"
      end

      def update_babushka_sources
        exec "babushka pull"
      end

      def babushka(dep, args = {})
        unless args.empty?
          stringified_args = args.map_keys(&:to_s).map_values { |v| { 'values' => v } }
          vars = { :vars => stringified_args }.to_yaml
          exec "mkdir -pf ~/.babushka/vars"
          write_file("~/.babushka/vars/#{dep}") { |f| f << vars }
        end
        exec "babushka meet '#{dep}' --defaults"
      end

      def babushka_as(user, dep, args = {})
        as_user(user) { babushka dep, args }
      end
    end
  end
end
