$:. unshift(File.dirname(__FILE__))
require 'rubygems'
require 'set'
require 'genetox_interface'
require 'ccris_interface'

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
# Description :: Use the Genetox Ontology to select and build feature vectors for model building.

# to do:
#  + 

class FeatureVectorGenerator
    
    attr_accessor:terminal_classes,:renderer
    
    def initialize()
        # load the ontology
        begin
            @manager     = OWLManager.createOWLOntologyManager()
            file         = JavaIO::File.new("#{File.expand_path(File.join(File.dirname(__FILE__),"../ontologies/"))}/genetoxinferred.owl")
            @ontology    = @manager.loadOntologyFromOntologyDocument(file)
            @root        = @manager.getOWLDataFactory.getOWLClass(IRI.create("http://semanticscience.org/resource/genetox:Genetox_0047"))
        rescue NativeException => e
            STDERR.puts "Wasn't able to load the genetox ontology.\n Check it exits"
            STDERR.puts e.backtrace.join("\n")
            exit
        end
        
        # set up the renderer to output the classes.
        properties = JavaIO::ArrayList.new
        properties.add(@manager.getOWLDataFactory.getOWLAnnotationProperty(OWLRDFVocabulary::RDFS_LABEL.getIRI()))
        properties.add(@manager.getOWLDataFactory.getOWLAnnotationProperty(OWLRDFVocabulary::RDFS_COMMENT.getIRI()))
        provider = AnnotationValueShortFormProvider.new(properties,JavaIO::HashMap.new(),@manager)
        @renderer =  ManchesterOWLSyntaxOWLObjectRendererImpl.new
        @renderer.setShortFormProvider(provider)
    end
    
    
    def import_instances()
      
    end
    
    
    # build a set of feature fectors with attributes starting from most specialized
    # move up generalized classes by input distance.
    # + find chemicals that interset Genetox and CCRIS
    #   +grab all the classes we are going to look at.
    #       +get instances for each class.
    #       +find all instances that involve the chemical
    
    def build_feature_set(distance = 0)
        genetox = GenetoxInterface.new()
        ccris = CcrisInterface.new()
        
       
        g  = genetox.chemicals.collect {|solution| solution[:cas]}
        c  = ccris.chemicals.collect {|solution| solution[:cas]}
        chemicals = g & c
        
        classes  = find_classes(distance)
        
        
        chemicals.each do |chemical|
            vector = []
                classes.each do |cls|
                
                    instances = get_individuals(cls)
                    experiments = (genetox.get_experiments(cas) - instances)
                    
                    atr_value = genetox.calc_attr_value(experiments)
                    
                    vector << atr_value
                end
            
            vector << ccris.active?(chemical[:cas])
            
            puts vector.join(",")
        end
        
    end
    
    # retrive the instancs for a given class
    def get_individuals(cls)
        cls.getIndividuals(@ontology)
    end
    
    # find all classes that have no children starting from 'root' class.
    def find_terminal_classes(cls = @root)
        
        if(!@terminal_classes)
            return @terminal_classes
        else
            @terminal_classes = Set.new()
        
            sub_cls = cls.getSubClasses(@ontology)
        
            if(sub_cls.size == 0)
                @terminal_classes << cls 
            else
                sub_cls.each {|subCls| find_terminal_classes(subCls)}
            end
            
            return @terminal_classes
        end
    end
    
    # find all the classes that are 'distance' classes away from terminal. 
    def find_classes(distance)
        return find_terminal_classes if (distance == 0)
    end
end

FeatureVectorGenerator.new.build_feature_set()
