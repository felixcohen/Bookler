require 'action_controller/base'
require 'action_dispatch/http/mime_types'

module Princely
  class Railtie < Rails::Railtie

    initializer :init_mime_types do
      Mime::Type.register 'application/pdf', :pdf
    end

    initializer :insert_into_action_controller do
      ActiveSupport.on_load :action_controller  do
        ActionController::Base.send(:include, Princely::PdfHelper)
      end
    end
  end
end
