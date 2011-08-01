# encoding: utf-8
require 'test_helper'
require 'armot/puret_integration'

class PuretMigrationTest < ActiveSupport::TestCase
  def setup
    setup_db
    I18n.locale = I18n.default_locale = :en
    Post.create :title => "English title"
    Post.create :title => "Second english title"
    I18n::Backend::ActiveRecord::Translation.delete_all

    PostTranslation.create(:post_id => Post.first.id, :locale => "en", :title => 'English title', :text => "Some text")
    PostTranslation.create(:post_id => Post.first.id, :locale => "es", :title => 'Titulo español')
    PostTranslation.create(:post_id => Post.last.id, :locale => "en", :title => 'Second english title')
  end

  def teardown
    teardown_db
  end

  test "db setup" do
    assert_equal 0, I18n::Backend::ActiveRecord::Translation.count
    assert_equal 2, Post.count
    assert_equal 3, PostTranslation.count
  end

  test "armot should not work" do
    assert_equal nil, Post.first.title
  end

  test "should create i18n records for exiting puret translations" do
    Armot::PuretIntegration.migrate

    assert_equal 4, I18n::Backend::ActiveRecord::Translation.count
  end

  test "translations with armot should work after migrate" do
    Armot::PuretIntegration.migrate

    assert_equal "English title", Post.first.title
    assert_equal "Second english title", Post.last.title
  end

  test "non existing translations reamain the same" do
    Armot::PuretIntegration.migrate

    assert_equal nil, Post.last.text
  end

  test "should preserve translations" do
    Armot::PuretIntegration.migrate

    post = Post.first
    I18n.locale = :es
    assert_equal "Titulo español", post.title
    I18n.locale = :en
    assert_equal "English title", post.title
  end

end
