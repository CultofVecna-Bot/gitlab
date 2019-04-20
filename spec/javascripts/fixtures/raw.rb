require 'spec_helper'

describe 'Raw files', '(JavaScript fixtures)' do
  include JavaScriptFixturesHelpers

  let(:namespace) { create(:namespace, name: 'frontend-fixtures' )}
  let(:project) { create(:project, :repository, namespace: namespace, path: 'raw-project') }
  let(:response) { @blob.data.force_encoding('UTF-8') }

  before(:all) do
    clean_frontend_fixtures('blob/notebook/')
    clean_frontend_fixtures('blob/pdf/')
  end

  after do
    remove_repository(project)
  end

  it 'blob/notebook/basic.json' do |example|
    @blob = project.repository.blob_at('6d85bb69', 'files/ipython/basic.ipynb')

    store_frontend_fixture(response, example.description)
  end

  it 'blob/notebook/worksheets.json' do |example|
    @blob = project.repository.blob_at('6d85bb69', 'files/ipython/worksheets.ipynb')

    store_frontend_fixture(response, example.description)
  end

  it 'blob/notebook/math.json' do |example|
    @blob = project.repository.blob_at('93ee732', 'files/ipython/math.ipynb')

    store_frontend_fixture(response, example.description)
  end

  it 'blob/pdf/test.pdf' do |example|
    @blob = project.repository.blob_at('e774ebd33', 'files/pdf/test.pdf')

    store_frontend_fixture(response, example.description)
  end
end
