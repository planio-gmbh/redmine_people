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

class PeopleController < ApplicationController
  unloadable

  Mime::Type.register "text/x-vcard", :vcf

  before_filter :find_person, :only => [:show, :edit, :update, :destroy, :edit_membership, :destroy_membership]
  before_filter :authorize_people, :except => [:avatar, :context_menu, :autocomplete_tags]
  before_filter :bulk_find_people, :only => [:context_menu]

  include PeopleHelper
  helper :queries
  helper :departments
  helper :context_menus
  helper :custom_fields
  helper :sort
  include SortHelper

  def index
    retrieve_people_query
    sort_init(@query.sort_criteria.empty? ? [['lastname', 'asc'], ['firstname', 'asc']] : @query.sort_criteria)
    sort_update(@query.sortable_columns)
    @query.sort_criteria = sort_criteria.to_a

    if @query.valid?
      case params[:format]
      when 'csv', 'pdf', 'xls', 'vcf'
        @limit = Setting.issues_export_limit.to_i
      when 'atom'
        @limit = Setting.feeds_limit.to_i
      when 'xml', 'json'
        @offset, @limit = api_offset_and_limit
      else
        @limit = per_page_option
      end

      @people_count = @query.object_count

      if Redmine::VERSION.to_s > '2.5'
        @people_pages = Paginator.new(@people_count,  @limit, params[:page])
        @offset = @people_pages.offset
      else
        @people_pages = Paginator.new(self, @people_count,  @limit, params[:page])
        @offset = @people_pages.current.offset
      end

      @people_count_by_group = @query.object_count_by_group
      @people = @query.results_scope(
        :include => [:avatar],
        :search => params[:search],
        :order => sort_clause,
        :limit  =>  @limit,
        :offset =>  @offset
      )

      @groups = Group.all.sort
      @departments = Department.order(:name)

      @next_birthdays = Person.active
      @next_birthdays = @next_birthdays.visible if Redmine::VERSION.to_s >= "3.0"
      @next_birthdays = @next_birthdays.next_birthdays

      @new_people = Person.active
      @new_people = @new_people.visible if Redmine::VERSION.to_s >= "3.0"
      @new_people = @new_people.eager_load(:information).where("#{PeopleInformation.table_name}.appearance_date IS NOT NULL").order("#{PeopleInformation.table_name}.appearance_date desc").first(5)

      respond_to do |format|
        format.html {render :partial => people_list_style, :layout => false if request.xhr?}
      end

    end

  end

  def show
    unless @person.visible?
      render_404
      return
    end
    # @person.roles = Role.new(:permissions => [:download_attachments])
    events = Redmine::Activity::Fetcher.new(User.current, :author => @person).events(nil, nil, :limit => 10)
    @events_by_day = events.group_by(&:event_date)
    @person_attachments = @person.attachments.select{|a| a != @person.avatar}
    @memberships = @person.memberships.where(Project.visible_condition(User.current))
    respond_to do |format|
      format.html
    end
  end

  def edit
    @auth_sources = AuthSource.all
    @departments = Department.all.sort
    @membership ||= Member.new
    @person.build_information unless @person.information
  end

  def new
    @person = Person.new(:language => Setting.default_language, :mail_notification => Setting.default_notification_option)
    @person.build_information
    @person.safe_attributes = { 'information_attributes' => { 'department_id' => params[:department_id] }}

    @auth_sources = AuthSource.all
    @departments = Department.all.sort
  end

  def update
    (render_403; return false) unless @person.editable_by?(User.current)
    @person.safe_attributes = params[:person]
    if @person.save
      flash[:notice] = l(:notice_successful_update)
      attach_avatar
      attachments = Attachment.attach_files(@person, params[:attachments])
      render_attachment_warning_if_needed(@person)
      respond_to do |format|
        format.html { redirect_to :action => "show", :id => @person }
        format.api  { head :ok }
      end
    else
      respond_to do |format|
        format.html { render :action => "edit"}
        format.api  { render_validation_errors(@person) }
      end
    end
  end

  def create
    @person  = Person.new(:language => Setting.default_language, :mail_notification => Setting.default_notification_option)
    @person.safe_attributes = params[:person]
    @person.admin = false
    @person.login = params[:person][:login]
    @person.password, @person.password_confirmation = params[:person][:password], params[:person][:password_confirmation] unless @person.auth_source_id
    @person.type = 'User'
    if @person.save
      @person.pref.attributes = params[:pref] if params[:pref]
      @person.pref[:no_self_notified] = (params[:no_self_notified] == '1')
      @person.pref.save
      @person.notified_project_ids = (@person.mail_notification == 'selected' ? params[:notified_project_ids] : [])
      attach_avatar
      Mailer.account_information(@person, params[:person][:password]).deliver if params[:send_information]

      respond_to do |format|
        format.html {
          flash[:notice] = l(:notice_successful_create, :id => view_context.link_to(@person.login, person_path(@person)))
          redirect_to(params[:continue] ?
            {:controller => 'people', :action => 'new'} :
            {:controller => 'people', :action => 'show', :id => @person}
          )
        }
        format.api  { render :action => 'show', :status => :created, :location => person_url(@person) }
      end
    else
      @auth_sources = AuthSource.all
      # Clear password input
      @person.password = @person.password_confirmation = nil

      respond_to do |format|
        format.html { render :action => 'new' }
        format.api  { render_validation_errors(@person) }
      end
    end
  end

  def destroy
    @person.destroy
    respond_to do |format|
      format.html { redirect_back_or_default(people_path) }
    end
  end

  def avatar
    attachment = Attachment.find(params[:id])
    if attachment.readable? && attachment.thumbnailable?
      # images are sent inline
      if (defined?(RedmineContacts::Thumbnail) == 'constant') && Redmine::Thumbnail.convert_available?
        target = File.join(attachment.class.thumbnails_storage_path, "#{attachment.id}_#{attachment.digest}_#{params[:size]}.thumb")
        thumbnail = RedmineContacts::Thumbnail.generate(attachment.diskfile, target, params[:size])
      elsif Redmine::Thumbnail.convert_available?
        thumbnail = attachment.thumbnail(:size => params[:size])
      else
        thumbnail = attachment.diskfile
      end

      if stale?(:etag => attachment.digest)
        send_file thumbnail, :filename => (request.env['HTTP_USER_AGENT'] =~ %r{MSIE} ? ERB::Util.url_encode(attachment.filename) : attachment.filename),
                                        :type => detect_content_type(attachment),
                                        :disposition => 'inline'
      end

    else
      # No thumbnail for the attachment or thumbnail could not be created
      render :nothing => true, :status => 404
    end

  rescue ActiveRecord::RecordNotFound
    render :nothing => true, :status => 404
  end

  def context_menu
    @person = @people.first if (@people.size == 1)
    @can = {:edit =>  @people.collect{|c| User.current.allowed_people_to?(:edit_people, @person)}.inject{|memo,d| memo && d}
            }

    # @back = back_url
    render :layout => false
  end

private
  def authorize_people
    allowed = case params[:action].to_s
      when "create", "new"
        User.current.allowed_people_to?(:add_people, @person)
      when "update", "edit"
        User.current.allowed_people_to?(:edit_people, @person)
      when "destroy"
        User.current.allowed_people_to?(:delete_people, @person)
      when "index", "show"
        User.current.allowed_people_to?(:view_people, @person)
      else
        false
      end

    if allowed
      true
    else
      deny_access
    end
  end

  def attach_avatar
    if params[:person_avatar]
      params[:person_avatar][:description] = 'avatar'
      @person.avatar.destroy if @person.avatar
      Attachment.attach_files(@person, {"1" => params[:person_avatar]})
      render_attachment_warning_if_needed(@person)
    end
  end

  def detect_content_type(attachment)
    content_type = attachment.content_type
    if content_type.blank?
      content_type = Redmine::MimeType.of(attachment.filename)
    end
    content_type.to_s
  end

  def find_person
    if params[:id] == 'current'
      require_login || return
      @person = User.current
    else
      @person = Person.find(params[:id])
    end
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def bulk_find_people
    @people = Person.where(:id => params[:id] || params[:ids])
    raise ActiveRecord::RecordNotFound if @people.empty?
    if @people.detect {|person| !person.visible? }
      deny_access
      return
    end
  rescue ActiveRecord::RecordNotFound
    render_404
  end


end
