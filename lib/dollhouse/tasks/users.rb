module Dollhouse
  module Tasks
    module Users
      def setup_users(users)
        users.each do |login, attributes|
          create_user login, attributes
        end
      end

      def create_user(login, attributes)
        babushka 'trike admin user setup', {
          :login => login,
          :uid => attributes['uid'],
          :password_hash => attributes['password_hash'],
          :ssh_key => attributes['ssh_key']
        }
      end
    end
  end
end
