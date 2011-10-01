#
#  ccris_interface.rb
#  
#
#  Created by Dana Klassen on 11-09-29.
#  Copyright 2011 __MyCompanyName__. All rights reserved.
#



require 'rubygems'
require 'sparql/client'
require 'rdf'
require 'rdf/ntriples'

class CcrisInterface
    
    PREFIX = "PREFIX rdf:  <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
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
    
    # decide if chemical is active or not.
    def active?(cas)
        results = []
        
        get_experiments(cas).each do |exp|
            
            results << result(exp[:assay])
        end
        
        if results.size >0 
                  positive = results.count {|statement| statement[:result].to_s.include?("POSITIVE") == true}
                  negative = results.count {|statement| statement[:result].to_s.include?("NEGATIVE") == true}
                  noconclusion = results.count {|statement| statement[:result].to_s.include?("NO CONCLUSION") == true }

                  if(positive >= negative)
                    return "ACTIVE"
                  elsif(negative > positive)
                    return "INACTIVE"
                  elsif(negative == 0 && positive == 0 && noconclusion != 0)
                    return "INACTIVE"
                  else
                    return "?"
                  end

            end
      
    end
    
    # return result for given uri
    def result(exp)
        @sparql.query("#{PREFIX} 
                      SELECT ?result 
                      FROM <ccris>
                      WHERE{ 
                      \<#{exp}\> a ccris:Assay;ccris:hasResult ?res . ?res rdf:value ?result .}")
    end
    
    def query(query)
      begin
        return @sparql.query(query)
      rescue SPARQL::Client::MalformedQuery => e
        STDERR.puts "Query error:"
        STDERR.puts e.backtrace.join("\n")
      end
    end
    
    # get all the experiments for a CAS number
    def get_experiments(cas)
        query = PREFIX
        query = "#{PREFIX}
                 SELECT ?assay
                 FROM <ccris>
                 WHERE{
                   ?assay genetox:hasSubstance ?substance .
                   ?substance genetox:hasCasRegistryNumber #{cas} .
                 }"
        query(query)
    end
    
    # get unique cas registry numbers from the genetox linked data resource.
    def chemicals
        begin 
            return @sparql.query("#{PREFIX} \n SELECT DISTINCT(?cas) \n FROM <ccris> \n WHERE { \n [] ccris:hasCasRegistryNumber ?cas . \n ?cas a bio2rdf:CasRN . \n }")
        rescue SPARQL::Client::MalformedQuery => e
            STDERR.puts "Query error:"
            STDERR.puts e.backtrace.join("\n")
        end
    end
    
end