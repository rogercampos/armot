require 'test_helper'


def to_method_name(name)
  if Gem::Version.new(RUBY_VERSION.dup) >= Gem::Version.new("1.9")
    name.to_sym
  else
    name.to_s
  end
end

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

  test "should look for translations in other languages before fail" do
    post = Post.first
    I18n::Backend::ActiveRecord::Translation.delete_all
    I18n.locale = :ca
    post.title = "Catalan title"
    post.save!
    I18n.locale = :it
    assert_equal "Catalan title", post.title
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

    foo = Post.find_by_title! "Catalan title"
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

  test "should return nil when finding for an existant value but incompatible with the current scope" do
    post = Post.first
    I18n.locale = :ca
    post.title = "Catalan title"
    post.save!

    foo = Post.where("title != 'Catalan title'").find_by_title "Catalan title"
    assert_equal nil, foo
  end

  test "should raise a RecordNotFound error when finding for an existant value but incompatible with the current scope with bang!" do
    post = Post.first
    I18n.locale = :ca
    post.title = "Catalan title"
    post.save!

    assert_raise(ActiveRecord::RecordNotFound) do
      Post.where("title != 'Catalan title'").find_by_title! "Catalan title"
    end
  end

  test "should raise exception with bang version" do
    assert_raise(ActiveRecord::RecordNotFound) do
      Post.find_by_title! "Non existant"
    end
  end

  test "should find by translated title without translations" do
    post = Post.first
    post[:title] = "Eng title"
    post.save!

    I18n::Backend::ActiveRecord::Translation.delete_all

    foo = Post.find_by_title "Eng title"
    assert_not_equal nil, foo
    assert_nothing_raised do
      foo = Post.find_by_title! "Eng title"
    end
  end

  test "should return nil when no translations and no match" do
    post = Post.first
    post[:title] = "Eng title"
    post.save!

    I18n::Backend::ActiveRecord::Translation.delete_all

    foo = Post.find_by_title "Wrong title"
    assert_equal nil, foo
  end

  test "should raise an exception when no translationts and no match, with a bang" do
    post = Post.first
    post[:title] = "Eng title"
    post.save!

    I18n::Backend::ActiveRecord::Translation.delete_all

    assert_raise(ActiveRecord::RecordNotFound) do
      Post.find_by_title! "Non existant"
    end
  end

  test "_changed? method should work as expected" do
    post = Post.first
    post.title = "Other title"

    assert_equal true, post.title_changed?

    post.save!
    assert_equal false, post.title_changed?

    post.title = "Another change"
    assert_equal true, post.title_changed?
  end

  test "should find the correct record when there are conflicting names and scopes" do
    post = Post.first
    post.title = "Hola"
    post.header = "1"
    post.save!

    post2 = Post.create! :title => "Hola", :header => "2"

    foo = Post.where(:header => "2").find_by_title "Hola"
    assert_equal post2, foo
  end

  test "should find the correct record when there are conflicting names and scopes with bang" do
    post = Post.first
    post.title = "Hola"
    post.header = "1"
    post.save!

    post2 = Post.create! :title => "Hola", :header => "2"

    assert_nothing_raised do
      Post.where(:header => "2").find_by_title! "Hola"
    end
  end

  test "should not mix armotized class methods" do
    foo = Comment.methods.include?(to_method_name(:find_by_title))
    assert_equal false, foo
  end

  test "should not mix armotized class methods in Post" do
    foo = Post.methods.include?(to_method_name(:find_by_msg))
    assert_equal false, foo
  end

  test "should include the method in Comment" do
    foo = Comment.methods.include?(to_method_name(:find_by_msg))
    assert_equal true, foo
  end

  test "should include the method in Post" do
    foo = Post.methods.include?(to_method_name(:find_by_title))
    assert_equal true, foo
  end

  test "should be able to use super from an overrided setter for instance methods" do
    # Product class has 'name' setter redefined
    a = Product.create

    I18n.locale = :ca
    a.name = "Catalan foo"

    I18n.locale = :en
    a.name = "English foo"
    a.save!

    a.reload

    I18n.locale = :ca
    assert_equal "Catalan foo customized", a.name
    I18n.locale = :en
    assert_equal "English foo customized", a.name
  end

  test "should be able to use super for class methods" do
    a = Product.create
    I18n.locale = :ca
    a.name = "Catalan foo"

    I18n.locale = :en
    a.name = "English foo"
    a.save!

    a.reload
    I18n.locale = :ca

    res = Product.find_by_name("Catalan foo customized")
    assert_equal "Catalan foo customized_override", res
  end
end
