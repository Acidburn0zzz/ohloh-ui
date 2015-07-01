class Project < ActiveRecord::Base
  include ProjectAssociations
  include LinkAccessors
  include Tsearch
  include ProjectSearchables
  include ProjectScopes
  include ProjectJobs

  acts_as_editable editable_attributes: [:name, :url_name, :logo_id, :organization_id, :best_analysis_id,
                                         :description, :tag_list, :missing_source, :url, :download_url],
                   merge_within: 30.minutes
  acts_as_protected
  acts_as_taggable
  link_accessors accessors: { url: :Homepage, download_url: :Download }

  validates :name, presence: true, length: 1..100, allow_nil: false, uniqueness: true, case_sensitive: false
  validates :url_name, presence: true, length: 1..60, allow_nil: false, uniqueness: true, case_sensitive: false
  validates :description, length: 0..800, allow_nil: true # , if: proc { |p| p.validate_url_name_and_desc == 'true' }
  validates_each :url, :download_url, allow_blank: true do |record, field, value|
    record.errors.add(field, I18n.t(:not_a_valid_url)) unless value.valid_http_url?
  end
  before_validation :clean_strings_and_urls
  after_save :update_organzation_project_count

  attr_accessor :managed_by_creator

  def to_param
    url_name.blank? ? id.to_s : url_name
  end

  def related_by_stacks(limit = 12)
    stack_weights = StackEntry.stack_weight_sql(id)
    Project.select('projects.*, shared_stacks, shared_stacks*sqrt(shared_stacks)/projects.user_count as value')
      .joins(sanitize("INNER JOIN (#{stack_weights}) AS stack_weights ON stack_weights.project_id = projects.id"))
      .not_deleted.where('shared_stacks > 2').order('value DESC, shared_stacks DESC').limit(limit)
  end

  def related_by_tags(limit = 5)
    tag_weights = Tagging.tag_weight_sql(self.class, tags.map(&:id))
    Project.select('projects.*, tag_weights.weight')
      .joins(sanitize("INNER JOIN (#{tag_weights}) AS tag_weights ON tag_weights.project_id = projects.id"))
      .not_deleted.where.not(id: id).order('tag_weights.weight DESC, projects.user_count DESC').limit(limit)
  end

  def active_managers
    Manage.projects.for_target(self).active.to_a.map(&:account)
  end

  def allow_undo_to_nil?(key)
    ![:name].include?(key)
  end

  def allow_redo?(key)
    (key == :organization_id && !organization_id.nil?) ? false : true
  end

  def main_language
    return if best_analysis.nil? || best_analysis.main_language.nil?
    best_analysis.main_language.name
  end

  def best_analysis
    super || NilAnalysis.new
  end

  def users(query = '', sort = '')
    search_term = query.present? ? ['accounts.name iLIKE ?', "%#{query}%"] : nil
    orber_by = sort.eql?('name') ? 'accounts.name ASC' : 'people.kudo_position ASC'

    Account.select('DISTINCT(accounts.id), accounts.*, people.kudo_position')
      .joins([{ stacks: :stack_entries }, :person])
      .where(stack_entries: { project_id: id })
      .where(search_term)
      .order(orber_by)
  end

  def code_published_in_code_search?
    koders_status.try(:ohloh_code_ready) == true
  end

  def self.cached_count
    # TODO: Enable Cache
    # get_cache('cached_project_count', :expires_in => 5.minutes) do
    Project.active.count
    # end
  end

  def newest_contributions
    contributions.sort_by_newest.includes(person: :account, contributor_fact: :primary_language).limit(10)
  end

  def top_contributions
    contributions.sort_by_twelve_month_commits
      .includes(person: :account, contributor_fact: :primary_language)
      .limit(10)
  end

  class << self
    def search_and_sort(query, sort, page)
      sort_by = (sort == 'relevance') ? nil : "by_#{sort}"
      tsearch(query, sort_by)
        .includes(:best_analysis)
        .paginate(page: page, per_page: 20)
    end
  end

  private

  def clean_strings_and_urls
    self.name = String.clean_string(name)
    self.description = String.clean_string(description)
  end

  def sanitize(sql)
    Project.send :sanitize_sql, sql
  end

  def update_organzation_project_count
    org = Organization.where(id: organization_id || organization_id_was).first
    return unless org
    org.update_attributes(editor_account: editor_account, projects_count: org.projects.count)
  end
end
