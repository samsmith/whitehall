class RemoveOldUsers < ActiveRecord::Migration
  def up
    users_to_keep = Edition.includes(:authors).all.map(&:authors).flatten.uniq
  
    users = User.arel_table
    users_to_destroy = User.where(users[:uid].eq(nil).or(users[:email].eq(nil))) - users_to_keep
    users_to_destroy.map(&:destroy)
  end

  def down
    #noop
  end
end
