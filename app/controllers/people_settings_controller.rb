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

class PeopleSettingsController < ApplicationController
  unloadable
  menu_item :people_settings

  layout 'admin'
  before_filter :require_admin
  before_filter :find_acl, :only => [:index]

  helper :departments
  helper :people

  def index
    @departments = Department.all
  end

  def update
    settings = Setting.plugin_redmine_people
    settings = {} if !settings.is_a?(Hash)
    settings.merge!(params[:settings])
    Setting.plugin_redmine_people = settings
    flash[:notice] = l(:notice_successful_update)
    redirect_to :action => 'index', :tab => params[:tab]
  end

  def destroy
    PeopleAcl.delete(params[:id])
    find_acl
    respond_to do |format|
      format.html { redirect_to :controller => 'people_settings', :action => 'index'}
      format.js
    end
  end

  def autocomplete_for_user
    @principals = Principal.where(:status => [Principal::STATUS_ACTIVE, Principal::STATUS_ANONYMOUS]).like(params[:q]).order('type, login, lastname ASC').limit(100)
    render :layout => false
  end

  def create
    user_ids = params[:user_ids]
    acls = params[:acls]
    user_ids.each do |user_id|
      PeopleAcl.create(user_id, acls)
    end
    find_acl
    respond_to do |format|
      format.html { redirect_to :controller => 'people_settings', :action => 'index', :tab => 'acl'}
      format.js
    end
  end

private

  def find_acl
    @users_acl = PeopleAcl.all
  end

end
