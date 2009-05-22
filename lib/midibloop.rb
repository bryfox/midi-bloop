require 'rubygems'
require 'midilib'
require 'lib/bloops' # compiled on intel OS X (10.5.6)

# Extend MIDI Events to convert delta time to bloop time
module MIDI
  class Event
    
    # Bloop only supports whole notes (no ties)
    # If duration is longer than that, return multiple durations to 
    # comprise the entire length
    # @return an array of strings
    def bloop_durations(delta=@delta_time)
      durations = []
      while delta > 0 do
        if delta >= 384
          durations << '1'
          delta -= 384
          next
        else
          durations << ((1/delta.to_f)*384).to_i.to_s
          break
        end
      end
      durations
    end
    
  end
end


class MidiBloop
  
  include MIDI
  DEFAULT_FILE = 'Blackbird.mid'

  def midi_to_bloopdata(filename=DEFAULT_FILE)
    seq = Sequence.new()

    # Read from MIDI file
    seq = MIDI::Sequence.new()
    tempo = seq.tempo
    measures = seq.get_measures

    # we'll store it all in a hash
    bloopscore = {
      :tempo => tempo,
      :tracks => []
    }

    File.open(filename, 'rb') { | file |
      
        track_num = 0

        seq.read(file) { | track, num_tracks, i |
          # puts "read track #{track ? track.name : ''} (#{i} of #{num_tracks})"
          next if not track #or track.name == 'Clarinet'

            bloopscore[:tracks][track_num] = {
              :name => track.name,
              :instrument => track.instrument,
              :data => []
            }

            puts "reading track #{track_num}: #{track.name}"
            # puts "instrument name \"#{track.instrument}\""
            # puts "#{track.events.length} events"
            
            track.events.each do |e|
              # e.print_decimal_numbers = true # default = false (print hex)
              e.print_note_names = true # default = false (print note numbers)
              # just ignore all non-note events for now
              # delta time: 96 ticks == one quarter note
              if e.note?
                events = bloopscore[:tracks][track_num][:data]
                if e.note_on?
# print "on: #{e.delta_time} - "
#   puts e.note_to_s
# puts "ADDING REST(S): #{e.bloop_durations.inspect}" if e.delta_time > 0
                  bloopscore[:tracks][track_num][:data] += e.bloop_durations if e.delta_time > 0
                  bloopscore[:tracks][track_num][:data] << "#{e.note_to_s}"
                else
# print "off: #{e.delta_time} - "
#   puts e.note_to_s
                  # Find the corresponding note_on event and update its duration.
                  on_note_index = bloopscore[:tracks][track_num][:data].reverse!.index(e.note_to_s)

                  # Won't work if longer than a whole note!
                  bloopscore[:tracks][track_num][:data][on_note_index] = e.bloop_durations.shift + ":" + events[on_note_index].to_s
                  bloopscore[:tracks][track_num][:data].reverse!                  
                  puts "WARNING: greater than a whole note (#{e.bloop_durations.inspect})" if e.bloop_durations.size > 1
                  # hack! fill in rests after the note sounds to make up that space...
                  # bloopscore[:tracks][i][:data] += e.bloop_durations if e.bloop_durations.size > 0
                  
                end
              
              end
            end

            # ignore tracks with no data
            if bloopscore[:tracks][track_num][:data].empty?
              bloopscore[:tracks].delete_at track_num
              next
            end
            
            bloopscore[:tracks][track_num][:data] = bloopscore[:tracks][track_num][:data].join(' ')

            # puts bloopscore[:tracks][track_num][:data]
            
            track_num += 1
            

        }

    }

    # puts bloopscore.inspect
    bloopscore
  end

  def build_bloop
    b = Bloops.new
    b.tempo = @bloop_data[:tempo] * 2
    instruments = []
    
    @bloop_data[:tracks].each_with_index do |track, i|
      next if !track or !track[:data]
      instruments[i] = b.sound Bloops::SQUARE
      b.tune instruments[i], track[:data]
    end
    b
  end

  def initialize
    @bloop_data = midi_to_bloopdata
    @bloop = build_bloop
  end
  
  def play
    loop do
      @bloop.play
      sleep 0.02 while !@bloop.stopped?
    end
  end
  
end

