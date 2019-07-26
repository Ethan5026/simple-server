class OrganizationsPage < ApplicationPage

  ADD_NEW_ORGANIZATION_BUTTON = { css: 'nav.page-nav>a' }.freeze
  ORGANIZATION_NAME_TEXT_FIELD = { id: 'organization_name' }.freeze
  ORGANIZATION_DESCRIPTION_TEXT_FIELD = { id: 'organization_description' }.freeze
  CREATE_ORGANIZATION_BUTTON = { css: 'input.btn-primary'}.freeze
  ORG_NAME_LIST = { css: "div.card" }.freeze

  def create_new_organization(orgName, orgDesc)
    click(ADD_NEW_ORGANIZATION_BUTTON)
    type(ORGANIZATION_NAME_TEXT_FIELD, orgName)
    type(ORGANIZATION_DESCRIPTION_TEXT_FIELD, orgDesc)
    click(CREATE_ORGANIZATION_BUTTON)
  end

  def verify_organization_info()
    orgnameList = all_elements(ORG_NAME_LIST)
    orgnameList.each do |name|
      name.text.include? 'test'
    end
  end

  def delete_organization(org_name)
      within(:xpath ,"//a[text()='#{org_name}']/../../..") do
        find(:css ,'i.fa-trash-alt').click
      end
  end
end