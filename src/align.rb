require 'sketchup.rb'
require 'extensions.rb'

module PSF
    module Align
        unless file_loaded?(__FILE__)
            ex = SketchupExtension.new('Align', 'align/main')
            ex.description = 'Align face to face utility'
            ex.version     = '1.0.0'
            ex.copyright   = 'PSF'
            ex.creator     = 'PSF'
            Sketchup.register_extension(ex, true)
            file_loaded(__FILE__)
        end
    end
end
