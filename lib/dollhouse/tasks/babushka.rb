module Dollhouse
  module Tasks
    module Babushka
      def babushka(dep, args = {})
        unless args.empty?
          stringified_args = args.map_keys(&:to_s).map_values { |v| { 'values' => v } }
          vars = { :vars => stringified_args }.to_yaml
          write_file(".babushka/vars") { |f| f << vars }
        end
        exec "babushka meet '#{dep}' --defaults"
      end
    end
  end
end
