# frozen_string_literal: true
require_relative 'trajectory_list'
require_relative '../parameter_object'
module SteerSuite
  module SteersimPostprocessor
    def process_document(raw_doc)
      sobj = raw_doc.as_scenario_obj
      new_sobj = sobj.map_trajectory do |traj|
        oldelem = traj.elements
        newelem = oldelem.reduce({s:[], a:[oldelem.first]}) do |memo, pos|
          memo[:a] << (memo[:s].last || pos) if (pos-memo[:a].last).r > 0.08
          if (pos-memo[:a].last).r > 0.04
            memo[:a] << pos
            memo[:s] = []
          else
            memo[:s] << pos
          end
          memo
        end

        next nil unless newelem[:a].size <= 135

        compressed = newelem[:a].each_slice(5).map {|arr| arr.first }
        Data::TrajectoryList.new(compressed)
      end

      if new_sobj.nil?
        raw_doc.state = :rot
        raw_doc.save!
      else
        new_fname = new_sobj.to_file StorageLoader.get_path CONFIG['steersuite_process_pool']
        dup = raw_doc.dup
        dup.state = :processed
        SteerSuite.document(dup, new_fname)
        ParameterObjectRelation.new(from: raw_doc, to: dup, relation: :process).save!
      end

      print '.'
    end

    def process_unprocessed
      FileUtils.mkdir_p(StorageLoader.get_path(CONFIG['steersuite_process_pool']))
      unprocessed = ParameterObject.where.missing(:as_processor_relation).and ParameterObject.raw
      puts "Going to process #{unprocessed.size} files"
      unprocessed.each(&method(:process_document))
      nil
    end

  end

end