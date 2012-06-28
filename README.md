Armot
=====

[![Build Status](https://secure.travis-ci.org/rogercampos/armot.png)](http://travis-ci.org/rogercampos/armot)


Armot is a minimal rails 3 library for handle your model translations. It's
heavily based on [puret](https://github.com/jo/puret), by Johannes Jörg
Schmidt, as it does basically the same but relying on the i18n ActiveRecord
backend to store and fetch translations instead of custom tables.

Choosing between puret or armot is as always a decision based on your custom
requirements:

1. If your application is multilingual and it's translated with default yaml
   files with i18n Simple backend, you should definitely go with Puret. In this
   scenario your application contents are multilingual but doesn't dynamically
   change, they're always the same.

2. If your application is multilingual and also you want to give access to
   change it's contents, you might have chosen another i18n backend like
   activerecord to be able to edit the translations in live. In this case
   armot gives you some advantages:

   - Your translations are centralized. If you're giving your users (maybe the
     admins of the site) the ability to change it's multilingual contents, it
     means that you already have an interface to edit I18n translations. Use it
     to edit your model translations too.
   - Use all i18n advantages for free, like fallbacks or being able to speed up model
     translations with Flatten and Memoize.
   - Don't worry about eager loading translations every time you load translated
     models.
   - Easy to set up, no external tables.


Installing armot
----------------

First add the following line to your Gemfile:

    gem 'armot'

Using armot is pretty straightforward. Just add the following line to any
model with attributes you want to translate:

    class Product < ActiveRecord::Base
      armotize :name, :description
    end

This will make attributes 'name' and 'description' multilingual for the
product model.

If your application is already in production and with real contents, making an
attribute armotized won't do any difference. You can expect your models to
return their old values until you make some translations.


Usage
-----

Your translated model will have different contents for each locale transparently.

    I18n.locale = :en

    car = Product.create :name => "A car"
    car.name #=> A car

    I18n.locale = :es
    car.name = "Un coche"
    car.name #=> Un coche

    I18n.locale = :en
    car.name #=> A car

Armot also provides an implementation for the `_changed?` method, so you can
normally operate as if it was a standard active_record attribute.

    car = Car.create :name => "Ford"
    car.name = "Honda"

    car.name_chaned? #=> true
    car.save!
    car.name_changed? #=> false


Reloading caches
----------------

Be aware that armot doesn't take care of any cache expiration. If you're using
Memoize with I18n ActiveRecord backend you must remember to reload the
backend.

Armot provides the `reload_armot!` callback which is called on the
instance after performing the changes. For example:

    class Post < ActiveRecord::Base
      # ...

      def reload_armot!
        I18n.backend.reload!
        Rails.cache.clear
      end
    end


Find_by dynamic methods
-----------------------

Armot also writes the dynamic `find_by` and `find_by!` methods in order to
fetch a record from database given a specific content for an armotized
attribute. It will *only* look for translations in the current language, and
it will not perform any kind of fallback mechanism. For example:

    I18n.locale = :en
    post = Post.create :title => "Title in english"

    Post.find_by_title "Title in english" #=> <post>
    Post.find_by_title "Not found"  #=> nil
    Post.find_by_title! "Not found" #=> ActiveRecord::RecordNotFound raised

    I18n.locale = :es
    Post.find_by_title "Title in english" #=> nil


Fallbacks
---------

When reading the contents from an instance (not find_by methods) Armot works
with your current I18n setup for fallbacks, just as if you were performing a
I18n.t lookup.


Modularized implementation
--------------------------

All the methods Armot provides are implemented in modules injected in your
class (ArmotInstanceMethods and ArmotClassMethods). This means that you can
override them in order to include custom logic. For instance if you are
translating the `slug_url` attribute on your Post model, maybe you have a
setter like this:

    class Post
      def slug_url=(value)
        self[:slug_url] = ConvertToSafeUrl(value)
      end

      def to_param
        slug_url
      end
    end

Now if you want to armotize this slug_url attribute and still perform this
logic, you could do that:

    class Post
      def slug_url=(value)
        super(ConvertToSafeUrl(value))
      end
    end

Armotized_attributes
--------------------

You can get a list of all the currently armotized attributes on a class by
calling:

    Post.armotized_attributes #=> [:title, :text]


Defining localized accessors
----------------------------

There are situations in which it's useful for you to have localized accessors for
your armotized attributes, so you don't need to change the current language in
order to get the value for an attribute in that language, for instance:

    I18n.locale = :en
    post = Post.create :title => "ENG title"
    I18n.locale = :es
    post.title = "SP title"
    post.save!

    I18n.locale = :en
    post.title_en #=> "ENG title"
    post.title_es #=> "SP title"

Armot provides now an automatic way to define these methods:

    class Post
      define_localized_accessors_for :title
    end

This will make available the `title_en` and `title_en=` methods (also in every
other languages that may be available, as returned from
`I18n.available_locales`). You can also set up these methods for all your
armotized attributes using the `:all` keyword:


    class Post
      define_localized_accessors_for :all
    end

You can also explicitly set the locales in which the accessors should be
defined, using this syntax:

    class Post
      define_localized_accessors_for :all, :locales => [:klingon, :pt]
    end


Development with armot
----------------------

Since armot stores model translations in an I18n ActiveRecord backend, in
development you also need to use that backend in order to see model
translations.

If you're using Simple backend in development I recomend you to chain it with
the ActiveRecord backend, this way you can see both of them.

    I18n.backend = I18n::Backend::Chain.new(I18n::Backend::ActiveRecord.new, I18n.backend)



Migrating from puret
--------------------

If you want to migrate your current model translations from puret to armot,
simply run this rake task:

    rake armot:migrate_puret


