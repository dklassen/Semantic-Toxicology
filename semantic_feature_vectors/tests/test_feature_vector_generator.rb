$:. unshift(File.join(File.dirname(__FILE__),"../"))

require 'lib/feature_vector_generator'
require 'test/unit'

class TestFeatureVectorGenerator < Test::Unit::TestCase

    def setup
        @generator = FeatureVectorGenerator.new()
    end
    
    # are we finding terminal classes?
    def testfind_terminal_classes
         @generator.find_terminal_classes
         assert_not_nil(@generator.terminal_classes, "No subclasses found.")
    end  
end