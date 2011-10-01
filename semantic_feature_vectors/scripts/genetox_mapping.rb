#! /usr/share/jruby/bin/jruby
require 'rubygems'
require 'rdf'
require 'rdf/ntriples'
require 'rdf/n3'
require 'rdf/raptor'
require 'sparql/client'
require 'set'

# load the required java libraries
Dir["#{File.expand_path(File.join(File.dirname(__FILE__),"../bin/owlapi-3.2.4"))}/*.jar"].each {|jar| require jar}

include Java

begin
    # load the necessary classes
    java_import 'org.semanticweb.owlapi.apibinding.OWLManager'
    java_import 'org.semanticweb.owlapi.model.OWLOntology'
    java_import 'org.semanticweb.owlapi.model.IRI'
    java_import 'org.semanticweb.owlapi.model.AddAxiom'
    java_import 'org.semanticweb.owlapi.util.SimpleIRIMapper'
    java_import 'org.semanticweb.owlapi.vocab.OWLRDFVocabulary'
    java_import 'org.semanticweb.owlapi.vocab.OWL2Datatype'
    java_import 'org.semanticweb.owlapi.vocab.OWLFacet'
    java_import 'org.semanticweb.owlapi.util.OWLOntologyWalker'
    java_import 'org.semanticweb.owlapi.util.OWLOntologyWalkerVisitor'
    java_import 'org.semanticweb.owlapi.util.OWLOntologyMerger'
    java_import 'uk.ac.manchester.cs.owl.owlapi.mansyntaxrenderer.ManchesterOWLSyntaxOWLObjectRendererImpl'
    java_import 'org.semanticweb.owlapi.util.AnnotationValueShortFormProvider'
    java_import 'org.semanticweb.owlapi.util.DefaultPrefixManager'
    java_import 'org.semanticweb.owlapi.model.OWLLiteral'
    java_import 'java.util.Collections'

module JavaIO
    java_import 'java.io.File'
    java_import 'java.util.TreeSet'
    java_import 'java.util.List'
    java_import 'java.util.ArrayList'
    java_import 'java.util.HashMap'
end

rescue NameError => e
    STDERR.puts "couldn't find and load the necessary classes"
    exit
end


# Author :: Dana Klassen
# Description :: Map TOXNET linked data from Bio2RDF resource to the Genetox ontology.

# things to do :
# 1. get list of all genetox assay classes and labels from ontology
# 2. build construct statements using labels from ontology to match to assays in linked data.
# 3. output result statements in RDF file.

# file we are writting triples to
outfile = "#{File.expand_path(File.join(File.dirname(__FILE__),"../rdf/"))}/#{File.basename($0,".rb")}.n3"

# load the ontology
begin
    @manager    = OWLManager.createOWLOntologyManager()
    file        = JavaIO::File.new("#{File.join(File.dirname(__FILE__),"../ontologies/")}GenetoxOntology.owl")
    @ontology   = @manager.loadOntologyFromOntologyDocument(file)
    root        = @manager.getOWLDataFactory.getOWLClass(IRI.create("http://semanticscience.org/resource/genetox:Genetox_0047"))
rescue SystemError => e
    STDERR.puts "Wasn't able to load the genetox ontology.\n Check it exits"
    STDERR.puts e.backtrace.join("\n")
    exit
end


@assays = Set.new()

# Recursively decend the stated hierarchy of the ontology until bottom.
def process_subcls(cls)
   cls.getSubClasses(@ontology).each do |subCls|
        @assays << subCls
        process_subcls(subCls)
   end
end
 
process_subcls(root)

# associate URI with label.
map = Hash.new()
@assays.each do |cls|
    cls.getAnnotations(@ontology,@manager.getOWLDataFactory.getOWLAnnotationProperty(OWLRDFVocabulary::RDFS_LABEL.getIRI())).each do |label|
        map.store(cls.to_s,label.getValue.getLiteral)
    end
end

# set up SPARQL 
sparql = SPARQL::Client.new("http://134.117.108.116:8890/sparql",:timeout=>1000000)
prefix = "PREFIX rdf:  <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
          PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
          PREFIX genetox: <http://bio2rdf.org/genetox_resource:>
          PREFIX genetox_ontology: <http://semanticscience.org/resource/genetox:>"

RDF::Writer.for(:n3).open(outfile) do |writer|
    
    map.each_pair do |key,value|
        value = value.split("; ")
        
        species_label = value.last
        assay_label   = (value-value.last.to_a).to_s

        if(species_label != nil)
            
            construct = "CONSTRUCT{
                            ?assay a #{key} .
                        }
                        WHERE{
                            ?assay a genetox:Assay;
                                    genetox:hasAssayType ?type ;
                                    genetox:hasSpecies ?species .
                            ?species ?x \"#{species_label}\" .
                            ?type ?x \"#{assay_label}\".
                        }\n"
            
            
            sparql.query("#{prefix}\n#{construct}").each_statement do |statement|
                writer << statement
            end
        end
    end
    
end

