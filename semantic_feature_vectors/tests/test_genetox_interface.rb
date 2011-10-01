#
#  test_genetox_interface.rb
#  
#
#  Created by Dana Klassen on 11-09-29.
#  Copyright 2011 __MyCompanyName__. All rights reserved.
#


$:. unshift(File.join(File.dirname(__FILE__),"../"))

require 'lib/genetox_interface'
require 'test/unit'

class TestGenetoxInterface < Test::Unit::TestCase

    def setup
        @test_chemical = "<http://bio2rdf.org/cas:17804-35-2>"
        @interface = GenetoxInterface.new()
    end
    
    # are we able to retrieve the chemicals
    def test_chemicals
        chemicals = @interface.chemicals
        assert_not_nil(chemicals,"The array was empty")
        assert_instance_of(Array,chemicals)
    end
    
    def test_get_experiments()
       result = @interface.get_experiments(@test_chemical)
       assert_not_nil(result, "wasn't able to find experiments")
    end
    
    def test_result()
         
    end
 
    def test_calc_attr_value()
        value = @interface.calc_attr_value(@interface.get_experiments(@test_chemical))
        assert_equal("TRUE",value)
    end
    

    
end