class LinksController < SettingsController
  # layout_params :project_layout_params
  # before_action :check_project
  before_action :set_project
  before_action :set_link, only: [:edit, :update, :destroy]
  before_action :session_required, only: [:create, :new, :edit, :update]
  before_action :set_categories, only: [:create, :new, :edit, :update]

  def new
    @link = Link.new
    load_category_and_title
  end

  def create
    @link = @project.links.new(link_params)

    if @link.revive_or_create
      redirect_to project_links_path(@project), flash: { success: t('.success') }
    else
      load_category_and_title
      render :new, status: 422
    end
  end

  def edit
    load_category_and_title
  end

  def update
    if @link.update(link_params)
      redirect_to project_links_path(@project), flash: { success: t('.success') }
    else
      load_category_and_title
      render :edit, status: 422
    end
  end

  def index
    @links = Link.all
  end

  def destroy
    if @link.destroy
      redirect_to project_links_path(@project), flash: { success: t('.success') }
    else
      redirect_to request.referrer, status: :failure, flash: { error: t('.error') }
    end
  end

  private

  def special_auth_cases
    must_be_authorized(@project) if %w(new edit).include?(action_name)
  end

  def load_category_and_title
    @category_name = Link.find_category_by_id(params[:category_id]) || @link.category
    return unless @link && @category_name
    type = nil
    type = :Homepage if (@category_name.to_s == 'Homepage')
    type = :Downloads if (@category_name.to_s == 'Download')
    @link.title ||= type
  end

  def set_link
    @link = Link.find(params[:id])
  end

  def set_project
    @project = Project.from_param(params[:project_id]).first
  end

  def set_categories
    @categories = applicable_categories
  end

  def applicable_categories
    return Link::CATEGORIES if occupied_category_ids.empty? ||
                               %w(edit update).include?(action_name)

    Link::CATEGORIES.reject do |_k, category_id|
      occupied_category_ids.include?(category_id)
    end
  end

  def occupied_category_ids
    @project.links
      .where(link_category_id: Link::CATEGORIES.values_at(:Homepage, :Download))
      .pluck(:link_category_id)
  end

  def link_params
    params.require(:link).permit([:title, :url, :project_id, :link_category_id])
  end
end