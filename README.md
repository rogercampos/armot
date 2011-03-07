Armot
=====

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


Be aware that armot doesn't take care of any cache expiration. If you're using
Memoize with I18n ActiveRecord backend you must take care yourself to reload
the backend with an observer, for example.



Migrating from puret
--------------------

If you want to migrate your current model translations from puret to armot,
simply run this rake task:

    rake armot:migrate_puret


