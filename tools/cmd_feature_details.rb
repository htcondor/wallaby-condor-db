# feature_details:  List all feature details for documentation
#
# Copyright (c) 2012 Red Hat, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'mrg/grid/config/shell/entity_ops'

module Mrg
  module Grid
    module Config
      module Shell
        class DocFeatures < Command
          include EntityOps
          
          def self.opname
            "doc-features"
          end
          
          def self.description
            "Lists feature information for all feaures in the store in friendly documentation format."
          end
          
          def supports_options
            false
          end

          def act
            store.console.objects(:class=>"Feature").sort {|x,y| x.name <=> y.name}.each do |feature|
              obj = store.getFeature(feature.name)
              puts "#{feature.name}"
              puts "  description: #{feature.annotation}"
              puts "  conflicts: #{feature.conflicts.empty? ? "None" : feature.conflicts.join(", ")}"
              puts "  depends: #{feature.depends.empty? ? "None" : feature.depends.join(", ")}"
              puts "  included: #{feature.included_features.empty? ? "None" : feature.included_features.join(", ")}"
            end
            0
          end
        end
      end
    end
  end
end
