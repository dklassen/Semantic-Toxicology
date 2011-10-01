#
#  genetox_interface.rb
#  
#
#  Created by Dana Klassen on 11-09-29.
#  Copyright 2011 __MyCompanyName__. All rights reserved.
#

require 'rubygems'
require 'sparql/client'
require 'rdf'
require 'rdf/ntriples'

class GenetoxInterface
    
    PREFIX  = "PREFIX rdf:  <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
               PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
               PREFIX bio2rdf: <http://bio2rdf.org/resource:>
               PREFIX genetox: <http://bio2rdf.org/genetox_resource:>
               PREFIX ccris: <http://bio2rdf.org/ccris_resource:>"
    
    def initialize(options = {})
    
        @options = options.dup
        @options[:sparql]  ||= "http://134.117.108.116:8890/sparql"
        @options[:timeout] ||= 1000000
        
        @sparql = SPARQL::Client.new(@options[:sparql],:timeout => @options[:timeout])
    end
    
    # calculate a single value based on a set experimental results.
    def calc_attr_value(experiments)
        results = []
        
        experiments.each do |exp|
            
            results << result(exp[:assay])
        end
                
        if results.size >0 
            positive = results.count {|statement| statement.to_s.include?("Positive") == true}
            negative = results.count {|statement| statement.to_s.include?("Negative") == true}
            
            if(positive >= negative)
                    return "TRUE"
                elsif(negative > positive)
                    return "FALSE"
                else
                    return "?"
                end
            else
                return "?"
        end
    end
    
    # get unique cas registry numbers from the 
    # genetox linked data resource.
    def chemicals
        begin 
            return @sparql.query("#{PREFIX} \n SELECT DISTINCT(?cas) \n FROM <genetox> \n WHERE { \n [] genetox:hasCASRegistryNumber ?cas . \n ?cas a bio2rdf:CasRN . \n }")
        rescue SPARQL::Client::MalformedQuery => e
            STDERR.puts "Query error finding chemicals:"
            STDERR.puts e.backtrace.join("\n")
        end
    end
    
    # return result for given uri
    def result(exp)
        @sparql.query("#{PREFIX} 
                      SELECT ?result 
                      WHERE{ 
                      \<#{exp}\> a genetox:Assay;genetox:hasResult ?res . ?res rdf:value ?result .}")
    end
    
    
    # given a chemical and array of experimental URIS return thet set of results
    def get_experiments(cas)
        
        begin
            # query for all experiments of a chemical then do intersection with instances passed in. 
            tmp = @sparql.query("#{PREFIX}
                                SELECT ?assay
                                FROM <genetox>
                                WHERE{
                                    ?assay genetox:hasSubstance ?substance .
                                    ?substance genetox:hasCASRegistryNumber #{cas} .
                                }")
            return tmp
        rescue SPARQL::Client::MalformedQuery => e 
            STDERR.puts "error finding experimental URIS" + e.backtrace.join("\n")
        end
    end
    
end