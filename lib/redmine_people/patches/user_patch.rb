# This file is a part of Redmine CRM (redmine_contacts) plugin,
# customer relationship management plugin for Redmine
#
# Copyright (C) 2011-2015 Kirill Bezrukov
# http://www.redminecrm.com/
#
# redmine_people is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# redmine_people is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with redmine_people.  If not, see <http://www.gnu.org/licenses/>.

require_dependency 'project'
require_dependency 'principal'
require_dependency 'user'

module RedminePeople
  module Patches

    module UserPatch
      def self.included(base) # :nodoc:
        base.send(:include, InstanceMethods)

        base.class_eval do
          unloadable
          if ActiveRecord::VERSION::MAJOR >= 4
            has_one :avatar, lambda { where("#{Attachment.table_name}.description = 'avatar'")}, :class_name => "Attachment", :as  => :container, :dependent => :destroy
          else
            has_one :avatar, :class_name => "Attachment", :as  => :container, :conditions => "#{Attachment.table_name}.description = 'avatar'", :dependent => :destroy
          end
          acts_as_attachable_global
        end
      end

      module InstanceMethods
        # include ContactsHelper

        def project
          @project ||= Project.new
        end

        def allowed_people_to?(permission, person = nil)
          return true if admin?
          return true if person && person.is_a?(User) && person.id == self.id && [:view_people, :edit_people].include?(permission)
          return false unless RedminePeople.available_permissions.include?(permission)
          return true if permission == :view_people && self.is_a?(User) && !self.anonymous? && Setting.plugin_redmine_people["visibility"].to_i > 0

          (self.groups + [self]).map{|principal| PeopleAcl.allowed_to?(principal, permission) }.inject{|memo,allowed| memo || allowed }
        end

      end
    end

  end
end

unless User.included_modules.include?(RedminePeople::Patches::UserPatch)
  User.send(:include, RedminePeople::Patches::UserPatch)
end


