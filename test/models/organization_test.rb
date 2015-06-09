require 'test_helper'

class OrganizationTest < ActiveSupport::TestCase
  let(:org) { create(:organization) }

  it 'unclaims projects when destroyed and reclaims them when undestroyed' do
    proj1 = create(:project)
    proj2 = create(:project)
    proj1.update_attributes(organization_id: org.id)
    proj2.update_attributes(organization_id: org.id)
    pe1 = PropertyEdit.where(target: proj1, key: 'organization_id', value: org.id.to_s).first
    pe2 = PropertyEdit.where(target: proj2, key: 'organization_id', value: org.id.to_s).first
    pe1.undone.must_equal false
    pe2.undone.must_equal false
    org.destroy
    pe1.reload.undone.must_equal true
    pe2.reload.undone.must_equal true
    proj1.reload.organization_id.must_equal nil
    proj2.reload.organization_id.must_equal nil
    CreateEdit.where(target: org).first.redo!(create(:admin))
    pe1.reload.undone.must_equal false
    pe2.reload.undone.must_equal false
    proj1.reload.organization_id.must_equal org.id
    proj2.reload.organization_id.must_equal org.id
  end

  describe 'managed_by' do
    it 'should return all orgs managed by an account' do
      account = create(:account)
      create(:manage, account: account, target: org)
      Organization.managed_by(account).must_equal [org]
    end
  end

  describe 'from_param' do
    it 'should match organization url_name' do
      organization = create(:organization)
      Organization.from_param(organization.url_name).first.id.must_equal organization.id
    end

    it 'should match organization id as string' do
      organization = create(:organization)
      Organization.from_param(organization.id.to_s).first.id.must_equal organization.id
    end

    it 'should match organization id as integer' do
      organization = create(:organization)
      Organization.from_param(organization.id).first.id.must_equal organization.id
    end

    it 'should not match deleted organizations' do
      organization = create(:organization)
      Organization.from_param(organization.to_param).count.must_equal 1
      organization.destroy
      Organization.from_param(organization.to_param).count.must_equal 0
    end
  end

  describe 'sort_by_newest' do
    it 'org' do
      org_1 = create(:organization, name: 'test1')
      org_2 = create(:organization, name: 'test2')

      Organization.sort_by_newest.must_equal [org_2, org_1]
    end
  end

  describe 'sort_by_recent' do
    it 'org' do
      org_1 = create(:organization, name: 'test1', updated_at: Time.now + 5.days)
      org_2 = create(:organization, name: 'test2')

      Organization.sort_by_recent.must_equal [org_1, org_2]
    end
  end

  describe 'sort_by_name' do
    it 'org' do
      org_1 = create(:organization, name: 'test1')
      org_2 = create(:organization, name: 'test2')

      Organization.sort_by_name.must_equal [org_1, org_2]
    end
  end

  describe 'sort_by_projects' do
    it 'org' do
      org_1 = create(:organization, name: 'test1', projects_count: 5)
      org_2 = create(:organization, name: 'test2', projects_count: 10)

      Organization.sort_by_projects.must_equal [org_2, org_1]
    end
  end

  describe 'search_and_sort' do
    it 'should return sorted search results' do
      org_1 = create(:organization, name: 'test na1', projects_count: 5)
      org_2 = create(:organization, name: 'test na2', projects_count: 10)
      org_3 = create(:organization, name: 'test na3', projects_count: 9)

      Organization.search_and_sort('test', 'projects', nil).must_equal [org_2, org_3, org_1]
    end
  end

  describe 'affiliators_count' do
    it 'must return non zero count' do
      account = create(:account, organization_id: org.id)
      create_position(account: account)
      org.affiliators_count.must_equal 1
    end

    it 'must return zero if no positions found' do
      create(:account, organization_id: org.id)
      org.affiliators_count.must_equal 0
    end
  end
end
