# encoding: UTF-8

require 'test_helper'

def to_method_name(name)
  if Gem::Version.new(RUBY_VERSION.dup) >= Gem::Version.new("1.9")
    name.to_sym
  else
    name.to_s
  end
end

class ArmotTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::Pending

  def setup
    setup_db
    I18n.locale = I18n.default_locale = :en
    I18n.fallbacks.clear
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

  test 'validates_armotized_presence_of should work' do
    class ValidatedPost < Post
      validates_armotized_presence_of :title, %w{ en ca es }
    end

    post = ValidatedPost.new
    assert_equal false, post.valid?

    I18n.locale = :en
    post.title = 'English title'
    assert_equal false, post.valid?

    { :ca => 'Títol català', :es => 'Título castellano' }.each do |locale, title|
      I18n.locale = locale
      post.title = title
    end

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

  test "should respect I18n standard fallback system" do
    I18n.fallbacks.map :es => :ca
    post = Post.first
    I18n.locale = :ca
    post.title = "Bola de drac"
    I18n.locale = :en
    post.title = "Dragon ball"
    I18n.locale = :es
    post.save!
    assert_equal "Bola de drac", post.title
  end

  test "should return the fallback even if not saved" do
    I18n.fallbacks.map :es => :ca
    post = Post.first
    I18n.locale = :ca
    post.title = "Bola de drac"
    I18n.locale = :en
    post.title = "Dragon ball"
    I18n.locale = :es
    assert_equal "Bola de drac", post.title
  end

  test "should return db-column values even if not persisted" do
    post = Post.new
    post[:title] = "Hello world"
    assert_equal "Hello world", post.title
  end

  test "should fetch all translations with only one query with multiple armotized parameters" do
    pending "should be implemented in the active_record specific gem" do
      post = Post.first
      post.text = "English text"
      post.save!

      res = count_query_reads_for("I18n::Backend::ActiveRecord::Translation") do
        a = Post.first
        a.text
        a.title
      end

      assert_equal 1, res
    end
  end

  test "should not save the record if it has not changed" do
    pending "should be implemented in the active_record specific gem" do
      post = Post.last
      post.title = "ENG title"
      post.text = "English text"
      post.save!

      res = count_query_updates_for("I18n::Backend::ActiveRecord::Translation") do
        a = Post.first
        a.title = "ENG Second version"
        a.text = "English text"
        a.save!
      end

      assert_equal 1, res
    end
  end

  test ".armotized_attributes" do
    assert_equal [:title, :text], Post.armotized_attributes
  end

  test "multiple armotize calls raise an error" do
    assert_raise Armot::DoubleDeclarationError do
      class FooBar < ActiveRecord::Base
        armotize :foo
        armotize :bar
      end
    end
  end

  test "the setter method shold return the assigned value" do
    post = Post.last
    res = (post.title = "Foo bar title")
    assert_equal "Foo bar title", res
  end

  test "an armotized class should not have armotized accessors by default" do
    post = Post.last
    assert_equal false, post.respond_to?(:title_en)
  end

  test ".define_localized_accessors_for should define localized accessors for the current locales" do
    post = Post.last
    I18n.locale = :es
    post.title = "SP titulo"
    post.save! # Just save here to make I18n.available_locales aware of both :es and :en

    assert_equal [:es, :en].sort, I18n.available_locales.sort

    class FuzzBar < Post
      define_localized_accessors_for :title
    end

    foo = FuzzBar.new
    foo.title = "Cucamonga"
    foo.save!
    assert_equal true, foo.respond_to?(:title_en)
    assert_equal true, foo.respond_to?(:"title_en=")
    assert_equal true, foo.respond_to?(:title_es)
    assert_equal true, foo.respond_to?(:"title_es=")
  end

  test "localized getters behaviour" do
    class FuzzBar < Post
      define_localized_accessors_for :title
    end

    foo = FuzzBar.new
    foo.title = "EN - title"
    I18n.locale = :es
    foo.title = "ES - titulo"
    foo.save!

    I18n.locale = :en
    assert_equal "EN - title", foo.title_en
    assert_equal "ES - titulo", foo.title_es
  end

  test "localized setters behaviour" do
    class FuzzBar < Post
      define_localized_accessors_for :title
    end

    foo = FuzzBar.new
    foo.title = "EN - title"
    I18n.locale = :es
    foo.title = "ES - titulo"
    foo.save!

    I18n.locale = :en
    res = (foo.title_es = "Segundo titulo")
    assert_equal "Segundo titulo", foo.title_es
    assert_equal "Segundo titulo", res
  end

  test "after using localized accessors the I18n.locale should remain the same" do
    class FuzzBar < Post
      define_localized_accessors_for :title
    end

    foo = FuzzBar.new
    foo.title = "EN - title"
    I18n.locale = :es
    foo.title = "ES - titulo"
    foo.save!

    I18n.locale = :klingon
    foo.title_es = "Segundo titulo"
    foo.title_en
    assert_equal :klingon, I18n.locale
  end

  test "localized accessors should work for more than one attribute" do
    class FuzzBar < Post
      define_localized_accessors_for :title, :text
    end

    foo = FuzzBar.new
    foo.title = "EN - title"
    foo.text = "EN - body text"
    foo.save!
    assert_equal true, foo.respond_to?(:title_en)
    assert_equal true, foo.respond_to?(:"title_en=")
    assert_equal true, foo.respond_to?(:text_en)
    assert_equal true, foo.respond_to?(:"text_en=")
  end

  test ".define_localized_accessors_for :all" do
    class FuzzBar < Post
      define_localized_accessors_for :all
    end

    foo = FuzzBar.new
    foo.title = "EN - title"
    foo.text = "EN - body text"
    foo.save!
    assert_equal true, foo.respond_to?(:title_en)
    assert_equal true, foo.respond_to?(:"title_en=")
    assert_equal true, foo.respond_to?(:text_en)
    assert_equal true, foo.respond_to?(:"text_en=")
  end

  test "reload_localized_accessors_for" do
    class FuzzBar < Post
      define_localized_accessors_for :title
    end

    foo = FuzzBar.new
    foo.title = "EN - title"
    foo.save!

    assert_equal [:en].sort, I18n.available_locales.sort
    assert_equal false, foo.respond_to?(:title_sk)

    I18n.locale = :sk
    foo.title = "Skandinavian title"
    foo.save!

    assert_equal [:en, :sk].sort, I18n.available_locales.sort
    assert_equal false, foo.respond_to?(:title_sk)

    FuzzBar.reload_localized_accessors_for :title
    assert_equal true, foo.respond_to?(:title_sk)
  end

  test "should work if the I18n backend has not fallbacks" do
    with_no_method(I18n.singleton_class, :fallbacks) do
      assert_equal false, I18n.respond_to?(:fallbacks)

      post = Post.last
      I18n.locale = :pt
      assert_equal nil, post.title
    end
  end

  test "define_localized_accessors_for with specific locales" do
    class FuzzBarTwo < Post
      define_localized_accessors_for :title, :locales => [:love, :hate]
    end

    foo = FuzzBarTwo.new
    assert_equal true, foo.respond_to?(:title_love)
    assert_equal true, foo.respond_to?(:"title_love=")
    assert_equal true, foo.respond_to?(:title_hate)
    assert_equal true, foo.respond_to?(:"title_hate=")
  end
end
