# frozen_string_literal: true

namespace :users do
  desc 'Show a user'
  task :show, [:email] => :environment do |_task, args|
    ap User.find_by(email: args[:email])
  end

  desc 'Create a user'
  task :create, [:email] => :environment do |_task, args|
    print 'Password: '
    password = $stdin.noecho(&:gets)
    # So the user knows we're off the password prompt
    puts
    password.strip
    ap User.create(email: args[:email], password: password.strip)
  end

  desc 'Change whether a user is active'
  task :active, %i[email active] => :environment do |_task, args|
    user = User.find_by(email: args[:email])
    user.update(active: args[:active])
    ap user
  end

  desc 'Change collections and whether user has full access'
  task :collections, %i[email collections] => :environment do |_task, args|
    user = User.find_by(email: args[:email])

    if args[:collections] == "''"
      user.update(collections: [], full_access: true)
    else
      user.update(collections: args[:collections].split, full_access: false)
    end
    ap user
  end
end
