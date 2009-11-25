require 'rhubarb/rhubarb'
require 'decoratedarray'


module GridConfigStore
  # TODO: query-backed groups, store sesame info
  # XXX: should feature definitions be versioned?

  # A kind of param (integer, string, hostname, etc.)
  class Kind
    include Rhubarb::Persisting
    declare_column :description, :string
  end
  
  # A configuration parameter
  class Param
    include Rhubarb::Persisting
    declare_column :kind, :integer, :not_null, references(Kind)
    declare_column :name, :string
    declare_column :description, :string
    declare_column :not_null, :boolean
    declare_column :expert, :boolean
    declare_column :needs_restart, :boolean
  end
  
  # A label on a relationship between things (e.g. param/feature X
  # *conflicts with* param/feature Y)
  class ArcLabel
    include Rhubarb::Persisting
    declare_column :label, :string

    # Returns an ArcLabel that represents a conflict with a kind of
    # thing (e.g. ArcLabel.conflicts(:param) or ArcLabel.conflicts(:feature))
    
    def self.conflicts_with(kind)
      key = ("conflicts_with_" + kind).to_sym
      @kinds ||= {}
      @kinds[key] ||= ArcLabel.find_by_label(key.to_s) or ArcLabel.new(:label=>key.to_s)
    end
    
    # As conflicts_with, except it returns an edge describing a dependency
    def self.depends_on(kind)
      key = ("depends_on_" + kind).to_sym
      @kinds ||= {}
      @kinds[key] ||= ArcLabel.find_by_label(key.to_s) or ArcLabel.new(:label=>key.to_s)
    end

    
  end
  
  # A relationship between parameters
  class ParamArc
    include Rhubarb::Persisting
    declare_column :source, :integer, :not_null, references(Param, :on_delete=>:cascade)
    declare_column :dest, :integer, :not_null, references(Param, :on_delete=>:cascade)
    declare_column :label, :integer, :not_null, references(ArcLabel)
  end
  
  # A node in the pool
  class Node
    include Rhubarb::Persisting
    declare_column :name, :string
    declare_column :pool, :string
    
    # Returns a list of groups of which this node is a member.  Appending a 
    # NodeGroup object to this list will create an association between this 
    # node and the given group.
    def groups
      onpush = Proc.new do |grp|
        GroupMembership.create :node=>row_id, :nodegroup=>grp.row_id
      end
      contents = GroupMembership.find_by_node(self.row_id).map {|gm| gm.group }
      DecoratedArray.new :push_callback=>onpush, :contents=>contents
    end
  end
  
  # An explicitly- (TODO: or implicitly-) declared group of nodes
  class NodeGroup
    include Rhubarb::Persisting
    declare_column :name, :string
  end
  
  class GroupMembership
    include Rhubarb::Persisting
    declare_column :node, :integer, :not_null, references(Node, :on_delete => :cascade)
    declare_column :nodegroup, :integer, :not_null, references(NodeGroup, :on_delete => :cascade)

    alias :created :version
    alias :group :nodegroup 
    alias :group= :nodegroup=
  end
  
  class Feature
    include Rhubarb::Persisting
    declare_column :name, :string

    # Returns true if this feature conflicts with the supplied feature
    def conflicts?(f)
      @@feature_conflict ||= ArcLabel.conflicts_with :feature
      a_from = FeatureArc.arcs :source=>self, :dest=>f, :label=>@@feature_conflict
      a_to = FeatureArc.arcs :dest=>self, :source=>f, :label=>@@feature_conflict
      (a_from + a_to).size > 0
    end


    # Returns true if this feature depends on the supplied feature
    def dependence?(f)
      @@feature_depend ||= ArcLabel.depends_on :feature
      res = FeatureArc.arcs :source=>self, :dest=>f, :label=>@@feature_depend
      res.size > 0
    end

    # Returns true if this feature is depended on by the supplied feature
    def dependent?(f)
      @@feature_depend ||= ArcLabel.depends_on :feature
      res = FeatureArc.arcs :dest=>self, :source=>f, :label=>@@feature_depend
      res.size > 0
    end

    # Returns a list of features that conflict with this one.
    # Appending a Feature object to this list will create a "conflict"
    # association between this feature and that feature. 
    def conflicts
      @@feature_conflict ||= ArcLabel.conflicts_with :feature
      onpush = Proc.new do |f|
        if not self.conflicts? f
          FeatureArc.create :source=>self, :dest=>self, :label=>@@feature_conflict
        end
      end
      contents_src = FeatureArc.arcs_implicating :feature=>row_id, :label=>@@feature_conflict.row_id
      contents = contents_src.select {|fa| not fa.deleted }
      DecoratedArray.new :push_callback=>onpush, :contents=>contents
    end

    # Returns a list of features that depend on this one.  Appending a
    # Feature object to this list will create a "dependency"
    # association between this feature and that feature.  
    #
    # XXX: unlike the db-backed objects, the list returned by this
    # method could get stale.  Don't let it hang around for too long.
    def dependents(v=nil)
      @@feature_depend ||= ArcLabel.depends_on :feature

      onpush = ondelete = nil

      if v == nil
        v = SQLBUtil::timestamp
        onpush = Proc.new do |f|
          if not self.dependent? f
            FeatureArc.create :source=>self, :dest=>f, :label=>@@feature_depend
          end
        end

        ondelete = 
      end
      contents_src = FeatureArc.arcs_from :source=>self, :label=>@@feature_depend, :version=>v
      contents = contents_src.select {|fa| not fa.deleted }
      DecoratedArray.new :push_callback=>onpush, :contents=>contents
    end

    # Returns a list of features that this one depends on.
    # Appending a Feature object to this list will create a "dependency"
    # association between that feature and this feature. 
    def dependences(v=nil)
      @@feature_depend ||= ArcLabel.depends_on :feature

      onpush = nil
      ondelete = nil

      # XXX: log or throw an exception if we try to add/delete from a
      # non-current version?

      if v == nil
        v = SQLBUtil::timestamp
        onpush = Proc.new do |f|
          if not self.dependence? f
            FeatureArc.create :source=>f, :dest=>self, :label=>@@feature_depend
          end
        end

        ondelete = Proc.new do |f|
          f.deleted = true
        end
      end

      contents_src = FeatureArc.arcs_to :source=>self, :label=>@@feature_depend, :version=>v
      DecoratedArray.new :push_callback=>onpush, :delete_callback=>ondelete, :contents=>contents
    end

  end
  
  # A relationship between features
  class FeatureArc
    include Rhubarb::Persisting
    alias :created :version

    declare_column :source, :integer, :not_null, references(Feature, :on_delete=>:cascade)
    declare_column :dest, :integer, :not_null, references(Feature, :on_delete=>:cascade)
    declare_column :label, :integer, :not_null, references(ArcLabel)
    declare_column :deleted, :boolean, :default, 0

    declare_index_on :source, :dest, :label
    declare_index_on :source, :label
    declare_index_on :dest, :label

    # Finds arcs to the given feature with the given label
    # Named params include :feature, :label, and :version
    # If version is supplied, choose the most recent revision not more
    # recent than version.  If not, choose the most recent revision.
    def arcs_to(args)
      args = args.dup
      version = args.delete(:version)
      args[:dest] = args.delete(:feature)
      FeatureArc.find_freshest :group_by=>[:source,:dest,:label], :select_by=>args, :version=>version
    end

    # Finds arcs from the given feature with the given label
    # Named params include :feature, :label, and :version
    # If version is supplied, choose the most recent revision not more
    # recent than version.  If not, choose the most recent revision.
    def arcs_from(args)
      args = args.dup
      version = args.delete(:version)
      args[:source] = args.delete(:feature)
      FeatureArc.find_freshest :group_by=>[:source,:dest,:label], :select_by=>args, :version=>version
    end

    # Finds arcs from the given feature to the given feature, with the
    # given label.  Named params include :source, :dest, :label, and
    # :version.  If version is supplied, choose the most recent revision
    # not more recent than version.  If not, choose the most recent
    # revision.
    def arcs(args)
      args = args.dup
      version = args.delete(:version)
      FeatureArc.find_freshest :group_by=>[:source,:dest,:label], :select_by=>args, :version=>version
    end

    # Finds arcs implicating a given feature.
    # Parameters include :feature, :label, and :version; finds all
    # arcs from or to :feature that have label :label and are the
    # freshest version not later than :version.  If you don't specify
    # a version, you get the latest.
    def arcs_implicating(args)
      arcs_to(args) + args_from(args)
    end
  end
  
  # A relationship identifying which parameter/value pairs are implied
  # by a given feature
  class FeatureParamMembership
    include Rhubarb::Persisting
    alias :created :version

    declare_column :feature, :integer, :not_null, references(Feature, :on_delete=>:cascade)
    declare_column :param, :integer, :not_null, references(Param, :on_delete=>:cascade)
    declare_column :value, :string
    declare_column :enable, :boolean, :default, 1
  end
  
  class Configuration
    include Rhubarb::Persisting
    declare_column :name, :string, :not_null
  end
  
  class ConfigurationGroupFeatureMapping
    include Rhubarb::Persisting
    declare_column :configuration, :integer, :not_null, references(Configuration, :on_delete=>:cascade)
    declare_column :nodegroup, :integer, :not_null, references(NodeGroup, :on_delete=>:cascade)
    declare_column :feature, :integer, :not_null, references(Feature, :on_delete=>:cascade)
    declare_column :enable, :boolean, :default, 1

    alias :created :version
    
  end

  class ConfigurationGroupParamMapping
    include Rhubarb::Persisting
    alias :created :version

    declare_column :configuration, :integer, :not_null, references(Configuration, :on_delete=>:cascade)
    declare_column :nodegroup, :integer, :not_null, references(NodeGroup, :on_delete=>:cascade)
    declare_column :param, :integer, :not_null, references(Param, :on_delete=>:cascade)
    declare_column :value, :string
    declare_column :enable, :boolean, :default, 1
  end
    
  class ConfigurationDefaultFeatureMapping
    include Rhubarb::Persisting
    alias :created :version

    declare_column :configuration, :integer, :not_null, references(Configuration, :on_delete=>:cascade)
    declare_column :feature, :integer, :not_null, references(Feature, :on_delete=>:cascade)
    declare_column :enable, :boolean, :default, 1
  end

  # Versioning is transparent; we use created-on timestamps from the model
  class ConfigurationSnapshot
    include Rhubarb::Persisting
    alias :created :version

    declare_column :name, :string, :not_null
  end

end