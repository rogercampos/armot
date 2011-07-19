require 'test_helper'

class ArmotTest < ActiveSupport::TestCase
  def setup
    setup_db
    I18n.locale = I18n.default_locale = :en
    Post.create(:title => 'English title')
  end

  def teardown
    teardown_db
  end

  test "database setup" do
    assert_equal 1, Post.count
  end

  test "allow translation" do
    I18n.locale = :de
    Post.first.update_attribute :title, 'Deutscher Titel'
    assert_equal 'Deutscher Titel', Post.first.title
    I18n.locale = :en
    assert_equal 'English title', Post.first.title
  end

  test "assert fallback to default locale" do
    post = Post.first
    I18n.locale = :sv
    post.title = 'Svensk titel'
    I18n.locale = :en
    assert_equal 'English title', post.title
    I18n.locale = :de
    assert_equal 'English title', post.title
  end

  test 'validates_presence_of should work' do
    post = Post.new
    assert_equal false, post.valid?

    post.title = 'English title'
    assert_equal true, post.valid?
  end

  test 'temporary locale switch should not clear changes' do
    I18n.locale = :de
    post = Post.first
    post.text = 'Deutscher Text'
    assert !post.title.blank?
    assert_equal 'Deutscher Text', post.text
  end

  test 'temporary locale switch should work like expected' do
    post = Post.new
    post.title = 'English title'
    I18n.locale = :de
    post.title = 'Deutscher Titel'
    post.save
    assert_equal 'Deutscher Titel', post.title
    I18n.locale = :en
    assert_equal 'English title', post.title
  end

  test 'should remove unused I18n translation entries when instance is removed' do
    post = Post.first
    post.title = "English title"
    post.text = "Some text"
    post.save!
    assert_equal 2, I18n::Backend::ActiveRecord::Translation.count
    post.destroy
    assert_equal 0, I18n::Backend::ActiveRecord::Translation.count
  end

  test "should remove entries for all languages" do
    post = Post.first
    post.title = "English title"
    I18n.locale = :ca
    post.title = "Catalan title"
    post.save!
    assert_equal 2, I18n::Backend::ActiveRecord::Translation.count
    post.destroy
    assert_equal 0, I18n::Backend::ActiveRecord::Translation.count
  end

  test "should not remove other instance translations" do
    post = Post.first
    post.title = "English title"
    post.save!
    post2 = Post.create! :title => "Other english title"
    assert_equal 2, I18n::Backend::ActiveRecord::Translation.count
    post.destroy
    assert_equal 1, I18n::Backend::ActiveRecord::Translation.count
  end

  test "should return original attribute when there are no translations" do
    post = Post.first
    post[:title] = "original title"
    post.save!
    I18n::Backend::ActiveRecord::Translation.delete_all

    assert_equal "original title", Post.first.title
  end

  test "should find by translated title in database as a translation" do
    post = Post.first
    I18n.locale = :ca
    post.title = "Catalan title"

    I18n.locale = :en
    post.title = "English title"
    post.save!

    I18n.locale = :ca
    foo = Post.find_by_title "Catalan title"
    assert_not_equal nil, foo
    assert_equal "Catalan title", foo.title
  end

  test "should not find a translation in database that does not match the current locale" do
    post = Post.first
    I18n.locale = :ca
    post.title = "Catalan title"

    I18n.locale = :en
    post.title = "English title"
    post.save!

    foo = Post.find_by_title "Catalan title"
    assert_equal nil, foo
  end

  test "should find by translated title without translations" do
    post = Post.first
    post[:title] = "Eng title"
    post.save!

    I18n::Backend::ActiveRecord::Translation.delete_all

    foo = Post.find_by_title "Eng title"
    assert_not_equal nil, foo
  end

  test "should return nil when no translations and no match" do
    post = Post.first
    post[:title] = "Eng title"
    post.save!

    I18n::Backend::ActiveRecord::Translation.delete_all

    foo = Post.find_by_title "Wrong title"
    assert_equal nil, foo
  end
end
