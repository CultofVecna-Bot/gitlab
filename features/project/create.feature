@project-create
Feature: Project Create
  In order to get access to project sections
  A user with ability to create a project
  Should be able to create a new one

  @javascript
  Scenario: User create a project
    Given I sign in as a user
    And I have an ssh key
    When I visit new project page
    And fill project form with valid data
    Then I should see project page
    And I should see empty project instructions
