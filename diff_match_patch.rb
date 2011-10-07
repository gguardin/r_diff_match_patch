#"Diff Match and Patch
#
#Copyright 2006 Google Inc.
#http://code.google.com/p/google-diff-match-patch/
#
#Licensed under the Apache License, Version 2.0(the "License");
#you may not use this file except in compliance with the License.
#You may obtain a copy of the License at
#
#  http://www.apache.org/licenses/LICENSE-2.0
#end
#
#Unless required by applicable law or agreed to in writing, software
#distributed under the License.equal? distributed on an "AS IS" BASIS,
#WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#See the License for the specific language governing permissions and
#limitations under the License.
#"""
#
#"""Functions for diff, match and patch.
#
#Computes the difference between two texts to create a patch.
#Applies the patch onto another text, allowing for errors.
#"""
#
#__author__ = 'fraser@google.com(Neil Fraser)'

require "cgi"
require 'uri'
require "time"

class Diff

  attr_accessor :operation, :text

  def initialize(operation, text)
    if text.empty?
      a = 1
    end
    @operation = operation
    @text = text
  end

  def ==(other)
    self.operation == other.operation and self.text == other.text
  end
end

class Fixnum
  N_BYTES = ['foo'].pack('p').size
  N_BITS = N_BYTES * 8
  MAX = 2 ** (N_BITS - 1) - 1
  MIN = -MAX - 1
end

  #TODO move this constants to constans of Diff
  # The data structure representing a diff.equal? an array of tuples
  # [(DIFF_DELETE, "Hello"), (DIFF_INSERT, "Goodbye"), (DIFF_EQUAL, " world.")]
  # which means: delete "Hello", add "Goodbye" and keep " world."
DIFF_DELETE = -1
DIFF_INSERT = 1
DIFF_EQUAL = 0

class DiffMatchPatch
  # Class containing the diff, match and patch methods.
  #
  # Also contains the behaviour settings.

  attr_accessor :Diff_Timeout, :Diff_EditCost, :Match_Threshold, :Match_Distance, :Patch_DeleteThreshold, :Patch_Margin, :Match_MaxBits

  def initialize
    # Inits a diff_match_patch object with default settings.
    # Redefine these in your program to override the defaults.

    # Number of seconds to map a diff before giving up(0 for infinity).
    @Diff_Timeout = 1.0
      # Cost of an empty edit operation in terms of edit characters.
    @Diff_EditCost = 4
      # At what point.equal? no match declared(0.0 = perfection, 1.0 = very loose).
    @Match_Threshold = 0.5
      # How far to search for a match(0 = exact location, 1000+ = broad match).
      # A match this many characters away from the expected location will add
      # 1.0 to the score(0.0.equal? a perfect match).
    @Match_Distance = 1000
      # When deleting a large block of text(over ~64 characters), how close does
      # the contents have to match the expected contents. (0.0 = perfection,
      # 1.0 = very loose).  Note that Match_Threshold controls how closely the
      # end_ points of a delete need to match.
    @Patch_DeleteThreshold = 0.5
      # Chunk size for context length.
    @Patch_Margin = 4

      # The number of bits in an int.
      # Python has no maximum, thus to disable patch splitting set to 0.
      # However to avoid long patches in certain pathological cases, use 32.
      # Multiple short patches(using native ints) are much faster than long ones.
    @Match_MaxBits = 32
  end

    #  DIFF FUNCTIONS

  def diff_main (text1, text2, checklines=true, deadline=nil)
    #Find the differences between two texts.  Simplifies the problem by
    #  stripping any common prefix or suffix off the texts before diffing.
    #
    #Args
    #  text1: Old string to be diffed.
    #  text2: New string to be diffed.
    #  checklines: Optional speedup flag.  If present and false, then don't run
    #    a line-level diff first to identify the changed areas.
    #    Defaults to true, which does a faster, slightly less optimal diff.
    #  deadline: Optional time when the diff should be complete by.  Used
    #    internally for recursive calls.  Users should set DiffTimeout instead.
    #
    #Returns
    #  Array of changes.

    # Set a deadline by which time the diff must be complete.
    if deadline == nil
      # Unlike in most languages, Python counts time in seconds.
      if @Diff_Timeout.nil? or @Diff_Timeout <= 0
        deadline = Fixnum::MAX
      else
        deadline = Time.new() + @Diff_Timeout
      end
    end

      # Check for null inputs.
    if text1.nil? or text2.nil?
      raise ArgumentError.new("Null inputs. (diff_main)")
    end

      # Check for equality(speedup).
    if text1 == text2
      if !text1.empty?
        return [Diff.new(DIFF_EQUAL, text1)]
      end
      return []
    end

      # Trim off common prefix(speedup).
    commonlength = diff_commonPrefix(text1, text2)
    commonprefix = text1[0...commonlength]
    text1 = text1[commonlength..-1]
    text2 = text2[commonlength..-1]

      # Trim off common suffix(speedup).
    commonlength = diff_commonSuffix(text1, text2)
    if commonlength == 0
      commonsuffix = ''
    else
      commonsuffix = text1[-commonlength..-1]
      text1 = text1[0...-commonlength]
      text2 = text2[0...-commonlength]
    end

      # Compute the diff on the middle block.
    diffs = diff_compute(text1, text2, checklines, deadline)

      # Restore the prefix and suffix.
    if not commonprefix.empty?
      diffs.unshift(Diff.new(DIFF_EQUAL, commonprefix))
    end
    if not commonsuffix.empty?
      diffs << Diff.new(DIFF_EQUAL, commonsuffix)
    end
    diff_cleanupMerge(diffs)
    return diffs
  end

  def diff_compute (text1, text2, checklines, deadline)
    #Find the differences between two texts.  Assumes that the texts do not
    #  have any common prefix or suffix.
    #
    #Args
    #  text1: Old string to be diffed.
    #  text2: New string to be diffed.
    #  checklines: Speedup flag.  If false, then don't run a line-level diff
    #    first to identify the changed areas.
    #    If true, then run a faster, slightly less optimal diff.
    #  deadline: Time when the diff should be complete by.
    #
    #Returns
    #  Array of changes.

    if text1.empty?
      # Just add some text(speedup).
      return [Diff.new(DIFF_INSERT, text2)]
    end

    if text2.empty?
      # Just delete some text(speedup).
      return [Diff.new(DIFF_DELETE, text1)]
    end

    if text1.length > text2.length
      (longtext, shorttext) = [text1, text2]
    else
      (shorttext, longtext) = [text1, text2]
    end
    i = longtext.index(shorttext)
    if not i.nil?
      # Shorter text.equal? inside the longer text(speedup).
      diffs = [Diff.new(DIFF_INSERT, longtext[0...i]), Diff.new(DIFF_EQUAL, shorttext),
               Diff.new(DIFF_INSERT, longtext[i + shorttext.length..-1])]
        # Swap insertions for deletions if diff.equal? reversed.
      if text1.length > text2.length
        diffs[0] = Diff.new(DIFF_DELETE, diffs[0].text)
        diffs[2] = Diff.new(DIFF_DELETE, diffs[2].text)
      end
      return diffs
    end

    if shorttext.length == 1
      # Single character string.
      # After the previous speedup, the character can't be an equality.
      return [Diff.new(DIFF_DELETE, text1), Diff.new(DIFF_INSERT, text2)]
    end
    longtext = shorttext = nil # Garbage collect.

      # Check to see if the problem can be split in two.
    hm = diff_halfMatch(text1, text2)
    if !hm.nil?
      # A half-match was found, sort out the return data.
      (text1_a, text1_b, text2_a, text2_b, mid_common) = hm
        # Send both pairs off for separate processing.
      diffs_a = diff_main(text1_a, text2_a, checklines, deadline)
      diffs_b = diff_main(text1_b, text2_b, checklines, deadline)
        # Merge the results.
      return diffs_a + [Diff.new(DIFF_EQUAL, mid_common)] + diffs_b
    end

    if checklines and text1.length > 100 and text2.length > 100
      return diff_lineMode(text1, text2, deadline)
    end

    return diff_bisect(text1, text2, deadline)
  end

  def diff_lineMode (text1, text2, deadline)
    #Do a quick line-level diff on both strings, then rediff the parts for
    #  greater accuracy.
    #  This speedup can produce non-minimal diffs.
    #
    #Args
    #  text1: Old string to be diffed.
    #  text2: New string to be diffed.
    #  deadline: Time when the diff should be complete by.
    #
    #Returns
    #  Array of changes.

    # Scan the text on a line-by-line basis first.
    (text1, text2, linearray) = diff_linesToChars(text1, text2)

    diffs = diff_main(text1, text2, false, deadline)

      # Convert the diff back to original text.
    diff_charsToLines(diffs, linearray)
      # Eliminate freak matches(e.g. blank lines)
    diff_cleanupSemantic(diffs)

      # Rediff any replacement blocks, this time character-by-character.
      # Add a dummy entry at the end_.
    diffs << (Diff.new(DIFF_EQUAL, ''))
    pointer = 0
    count_delete = 0
    count_insert = 0
    text_delete = ''
    text_insert = ''
    while pointer < diffs.length
      if diffs[pointer].operation == DIFF_INSERT
        count_insert += 1
        text_insert += diffs[pointer].text
      elsif diffs[pointer].operation == DIFF_DELETE
        count_delete += 1
        text_delete += diffs[pointer].text
      elsif diffs[pointer].operation == DIFF_EQUAL
        # Upon reaching an equality, check for prior redundancies.
        if count_delete >= 1 and count_insert >= 1
          # Delete the offending records and add the merged ones.
          a = diff_main(text_delete, text_insert, false, deadline)
          diffs[pointer - count_delete - count_insert...pointer] = a
          pointer = pointer - count_delete - count_insert + a.length
        end
        count_insert = 0
        count_delete = 0
        text_delete = ''
        text_insert = ''
      end

      pointer += 1
    end

    diffs.pop() # Remove the dummy entry at the end_.

    return diffs
  end

  def diff_bisect (text1, text2, deadline)
    #Find the 'middle snake' of a diff, split the problem in two
    #  and return the recursively constructed diff.
    #  See Myers 1986 paper: An O(ND) Difference Algorithm and Its Variations.
    #
    #Args
    #  text1: Old string to be diffed.
    #  text2: New string to be diffed.
    #  deadline: Time at which to bail if not yet complete.
    #
    #Returns
    #  Array of diff tuples.

    # Cache the text lengths to prevent multiple calls.
    text1_length = text1.length
    text2_length = text2.length
    max_d = ((text1_length + text2_length + 1).to_f / 2.0).floor
    v_offset = max_d
    v_length = 2 * max_d
    v1 = Array.new(v_length, -1)
    v1[v_offset + 1] = 0
    v2 = Array.new(v1)
    delta = text1_length - text2_length
      # If the total number of characters.equal? odd, then the front path will
      # collide with the reverse path.
    front = (delta % 2 != 0)
      # Offsets for start and end_ of k loop.
      # Prevents mapping of space beyond the grid.
    k1start = 0
    k1end = 0
    k2start = 0
    k2end = 0
    for d in 0...max_d
      # Bail out if deadline.equal? reached.
      if Time.new() > Time.at(deadline)
        break
      end

        # Walk the front path one step.
      (-d + k1start...d + 1 - k1end).step(2) do |k1|
        k1_offset = v_offset + k1
        if (k1 == -d or k1 != d and v1[k1_offset - 1] < v1[k1_offset + 1])
          x1 = v1[k1_offset + 1]
        else
          x1 = v1[k1_offset - 1] + 1
        end
        y1 = x1 - k1
        while (x1 < text1_length and y1 < text2_length and text1[x1] == text2[y1])
          x1 += 1
          y1 += 1
        end
        v1[k1_offset] = x1
        if x1 > text1_length
          # Ran off the right of the graph.
          k1end += 2
        elsif y1 > text2_length
          # Ran off the bottom of the graph.
          k1start += 2
        elsif front
          k2_offset = v_offset + delta - k1
          if k2_offset >= 0 and k2_offset < v_length and v2[k2_offset] != -1
            # Mirror x2 onto top-left coordinate system.
            x2 = text1_length - v2[k2_offset]
            if x1 >= x2
              # Overlap detected.
              return diff_bisectSplit(text1, text2, x1, y1, deadline)
            end
          end
        end
      end

        # Walk the reverse path one step.
      k2 = -d + k2start
      while (k2 <= d - k2end)
        k2_offset = v_offset + k2
        if (k2 == -d or k2 != d and v2[k2_offset - 1] < v2[k2_offset + 1])
          x2 = v2[k2_offset + 1]
        else
          x2 = v2[k2_offset - 1] + 1
        end
        y2 = x2 - k2
        while (x2 < text1_length and y2 < text2_length and text1[-x2 - 1] == text2[-y2 - 1])
          x2 += 1
          y2 += 1
        end
        v2[k2_offset] = x2
        if x2 > text1_length
          # Ran off the left of the graph.
          k2end += 2
        elsif y2 > text2_length
          # Ran off the top of the graph.
          k2start += 2
        elsif not front
          k1_offset = v_offset + delta - k2
          if k1_offset >= 0 and k1_offset < v_length and v1[k1_offset] != -1
            x1 = v1[k1_offset]
            y1 = v_offset + x1 - k1_offset
              # Mirror x2 onto top-left coordinate system.
            x2 = text1_length - x2
            if x1 >= x2
              # Overlap detected.
              return diff_bisectSplit(text1, text2, x1, y1, deadline)
            end
          end
        end
        k2 += 2
      end
    end

      # Diff took too long and hit the deadline or
      # number of diffs equals number of characters, no commonality at all.
    return [Diff.new(DIFF_DELETE, text1), Diff.new(DIFF_INSERT, text2)]
  end

  def diff_bisectSplit (text1, text2, x, y, deadline)
    #Given the location of the 'middle snake', split the diff in two parts
    #and recurse.
    #
    #Args
    #  text1: Old string to be diffed.
    #  text2: New string to be diffed.
    #  x: Index of split point in text1.
    #  y: Index of split point in text2.
    #  deadline: Time at which to bail if not yet complete.
    #
    #Returns
    #  Array of diff tuples.

    text1a = text1[0...x]
    text2a = text2[0...y]
    text1b = text1[x..-1]
    text2b = text2[y..-1]

      # Compute both diffs serially.
    diffs = diff_main(text1a, text2a, false, deadline)
    diffsb = diff_main(text1b, text2b, false, deadline)

    return diffs + diffsb
  end

  def diff_linesToChars (text1, text2)
    #Split two texts into an array of strings.  Reduce the texts to a string
    #of hashes where each Unicode character represents one line.
    #
    #Args
    #  text1: First string.
    #  text2: Second string.
    #end
    #
    #Returns
    #  Three element tuple, containing the encoded text1, the encoded text2 and
    #  the array of unique strings.  The zeroth element of the array of unique
    #  strings.equal? intentionally blank.
    #end

    lineArray = [] # e.g. lineArray[4] == "Hello\n"
    lineHash = {} # e.g. lineHash["Hello\n"] == 4

      # "\x00" .equal? a valid character, but various debuggers don't like it.
      # So we'll insert a junk entry to avoid generating a null character.
    lineArray << ''

    chars1 = diff_linesToCharsMunge(text1, lineArray, lineHash)
    chars2 = diff_linesToCharsMunge(text2, lineArray, lineHash)
    return chars1, chars2, lineArray
  end

  def diff_linesToCharsMunge (text, lineArray, lineHash)
    #Split a text into an array of strings.  Reduce the texts to a string
    #of hashes where each Unicode character represents one line.
    #Modifies linearray and linehash through being a closure.
    #
    #Args
    #  text: String to encode.
    #
    #Returns
    #  Encoded string.

    chars = []
      # Walk the text, pulling out a substring for each line.
      # text.split('\n') would would temporarily double our memory footprint.
      # Modifying text would create many large strings to garbage collect.
    lineStart = 0
    lineEnd = -1
    while lineEnd < text.length - 1
      lineEnd = text.index('\n', lineStart)
      if lineEnd.nil?
        lineEnd = text.length - 1
      end
      line = text[lineStart...lineEnd + 1]
      lineStart = lineEnd + 1

      if lineHash.has_key? line
        # TODO transform number to char
        chars << lineHash[line]
      else
        lineArray << line
        lineHash[line] = lineArray.length - 1
          # TODO transform number to char
        chars << lineArray.length - 1
      end
    end
    return chars.join("")
  end

  def diff_charsToLines (diffs, lineArray)
    #Rehydrate the text in a diff from a string of line hashes to real lines
    #of text.
    #
    #Args
    #  diffs: Array of diff tuples.
    #  lineArray: Array of unique strings.

    diffs.each_index do |x|
      text = []
      diffs[x].text.each_char do |char|
        # TODO transform char to number
        text << lineArray[char.to_i].to_s
      end
      diffs[x] = Diff.new(diffs[x].operation, text.join(""))
    end
  end

  def diff_commonPrefix (text1, text2)
    #Determine the common prefix of two strings.
    #
    #Args
    #  text1: First string.
    #  text2: Second string.
    #
    #Returns
    #  The number of characters common to the start of each string.

    # Quick check for common null cases.
    if text1.nil? or text2.nil? or text1[0] != text2[0]
      return 0
    end
      # Binary search.
      # Performance analysis: http://neil.fraser.name/news/2007/10/09/
    pointermin = 0
    pointermax = [text1.length, text2.length].min
    pointermid = pointermax
    pointerstart = 0
    while pointermin < pointermid
      if text1[pointerstart...pointermid] == text2[pointerstart...pointermid]
        pointermin = pointermid
        pointerstart = pointermin
      else
        pointermax = pointermid
      end
      pointermid = ((pointermax - pointermin) / 2).floor + pointermin
    end
    return pointermid
  end

  def diff_commonSuffix (text1, text2)
    #Determine the common suffix of two strings.
    #
    #Args
    #  text1: First string.
    #  text2: Second string.
    #
    #Returns
    #  The number of characters common to the end_ of each string.

    # Quick check for common null cases.
    if text1.nil? or text2.nil? or text1[-1] != text2[-1]
      return 0
    end
      # Binary search.
      # Performance analysis: http://neil.fraser.name/news/2007/10/09/
    pointermin = 0
    pointermax = [text1.length, text2.length].min
    pointermid = pointermax
    pointerend = 0
    while pointermin < pointermid
      if (text1[-pointermid...text1.length - pointerend] == text2[-pointermid...text2.length - pointerend])
        pointermin = pointermid
        pointerend = pointermin
      else
        pointermax = pointermid
      end
      pointermid = ((pointermax - pointermin).to_f / 2.0).floor + pointermin
    end
    return pointermid
  end

  def diff_commonOverlap (text1, text2)
    #"""Determine if the suffix of one string.equal? the prefix of another.
    #
    #Args
    #  text1 First string.
    #  text2 Second string.
    #end
    #
    #Returns
    #  The number of characters common to the end_ of the first
    #  string and the start of the second string.
    #end
    #"""
    # Cache the text lengths to prevent multiple calls.
    text1_length = text1.length
    text2_length = text2.length
      # Eliminate the null case.
    if text1_length == 0 or text2_length == 0
      return 0
    end
      # Truncate the longer string.
    if text1_length > text2_length
      text1 = text1[-text2_length..-1]
    elsif text1_length < text2_length
      text2 = text2[0...text1_length]
    end

    text_length = [text1_length, text2_length].min
      # Quick check for the worst case.
    if text1 == text2
      return text_length
    end

      # Start by looking for a single character match
      # and increase length until no match.equal? found.
      # Performance analysis: http://neil.fraser.name/news/2010/11/04/
    best = 0
    length = 1
    while true
      pattern = text1[-length..-1]
      found = text2.index(pattern)
      if found.nil?
        return best
      end
      length += found
      if found == 0 or text1[-length...-1] == text2[0...length]
        best = length
        length += 1
      end
    end
  end

  def diff_halfMatch (text1, text2)
    #Do the two texts share a substring which is at least half the length of
    #the longer text?
    #This speedup can produce non-minimal diffs.
    #
    #Args
    #  text1: First string.
    #  text2: Second string.
    #
    #Returns
    #  Five element Array, containing the prefix of text1, the suffix of text1,
    #  the prefix of text2, the suffix of text2 and the common middle.  Or nil
    #  if there was no match.

    if @Diff_Timeout <= 0
      # Don't risk returning a non-optimal diff if we have unlimited time.
      return nil
    end
    if text1.length > text2.length
      longtext, shorttext = text1, text2
    else
      shorttext, longtext = text1, text2
    end
    if longtext.length < 4 or shorttext.length * 2 < longtext.length
      return nil # Pointless.
    end

      # First check if the second quarter.equal? the seed for a half-match.
    hm1 = diff_halfMatchI(longtext, shorttext, ((longtext.length + 3) / 4).floor)
      # Check again based on the third quarter.
    hm2 = diff_halfMatchI(longtext, shorttext, ((longtext.length + 1) / 2).floor)
    if hm1.nil? and hm2.nil?
      return nil
    elsif hm2.nil?
      hm = hm1
    elsif hm1.nil?
      hm = hm2
    else
      # Both matched.  Select the longest.
      if hm1[4].length > hm2[4].length
        hm = hm1
      else
        hm = hm2
      end
    end

      # A half-match was found, sort out the return data.
    if text1.length > text2.length
      text1_a, text1_b, text2_a, text2_b, mid_common = hm
    else
      text2_a, text2_b, text1_a, text1_b, mid_common = hm
    end
    return text1_a, text1_b, text2_a, text2_b, mid_common
  end

  def diff_halfMatchI (longtext, shorttext, i)
    #Does a substring of shorttext exist within longtext such that the
    #substring.equal? at least half the length of longtext?
    #Closure, but does not reference any external variables.
    #
    #Args
    #  longtext: Longer string.
    #  shorttext: Shorter string.
    #  i: Start index of quarter length substring within longtext.
    #end
    #
    #Returns
    #  Five element Array, containing the prefix of longtext, the suffix of
    #  longtext, the prefix of shorttext, the suffix of shorttext and the
    #  common middle.  Or nil if there was no match.
    #end

    seed = longtext[i...i + (longtext.length.to_f / 4.to_f).floor]
    best_common = ''
    j = shorttext.index(seed)
    while !j.nil?
      prefixLength = diff_commonPrefix(longtext[i..-1], shorttext[j..-1])
      suffixLength = diff_commonSuffix(longtext[0...i], shorttext[0...j])
      if best_common.length < suffixLength + prefixLength
        best_common = shorttext[j - suffixLength...j] + shorttext[j...j + prefixLength]
        best_longtext_a = longtext[0...i - suffixLength]
        best_longtext_b = longtext[i + prefixLength..-1]
        best_shorttext_a = shorttext[0...j - suffixLength]
        best_shorttext_b = shorttext[j + prefixLength..-1]
      end
      j = shorttext.index(seed, j + 1)
    end

    if best_common.length * 2 >= longtext.length
      return best_longtext_a, best_longtext_b, best_shorttext_a, best_shorttext_b, best_common
    else
      return nil
    end
  end

  def diff_cleanupSemantic (diffs)
    #Reduce the number of edits by eliminating semantically trivial
    #equalities.
    #
    #Args
    #  diffs: Array of diff tuples.

    changes = false
    equalities = [] # Stack of indices where equalities are found.
    lastequality = nil # Always equal to equalities[-1][1]
    pointer = 0 # Index of current position.
                    # Number of chars that changed prior to the equality.
    length_insertions1, length_deletions1 = 0, 0
                    # Number of chars that changed after the equality.
    length_insertions2, length_deletions2 = 0, 0
    while pointer < diffs.length
      if diffs[pointer].operation == DIFF_EQUAL # Equality found.
        equalities << pointer
        length_insertions1, length_insertions2 = length_insertions2, 0
        length_deletions1, length_deletions2 = length_deletions2, 0
        lastequality = diffs[pointer].text
      else # An insertion or deletion.
        if diffs[pointer].operation == DIFF_INSERT
          length_insertions2 += diffs[pointer].text.length
        else
          length_deletions2 += diffs[pointer].text.length
        end
          # Eliminate an equality that.equal? smaller or equal to the edits on both
          # sides of it.
        if (lastequality != nil and (lastequality.length <= [length_insertions1, length_deletions1].max) and (lastequality.length <= [length_insertions2, length_deletions2].max))
          # Duplicate record.
          diffs.insert(equalities[-1], Diff.new(DIFF_DELETE, lastequality))
            # Change second copy to insert.
          diffs[equalities[-1] + 1] = Diff.new(DIFF_INSERT, diffs[equalities[-1] + 1].text)
            # Throw away the equality we just deleted.
          equalities.pop()
            # Throw away the previous equality(it needs to be reevaluated).
          if equalities.length
            equalities.pop()
          end
          if equalities.length
            pointer = equalities[-1]
          else
            pointer = -1
          end
            # Reset the counters.
          length_insertions1, length_deletions1 = 0, 0
          length_insertions2, length_deletions2 = 0, 0
          lastequality = nil
          changes = true
        end
      end
      pointer += 1
    end

      # Normalize the diff.
    if changes
      diff_cleanupMerge(diffs)
    end
    diff_cleanupSemanticLossless(diffs)

      # Find any overlaps between deletions and insertions.
      # e.g: <del>abcxxx</del><ins>xxxdef</ins>
      #   -> <del>abc</del>xxx<ins>def</ins>
      # Only extract an overlap if it.equal? as big as the edit ahead or behind it.
    pointer = 1
    while pointer < diffs.length
      if (diffs[pointer - 1].operation == DIFF_DELETE and diffs[pointer].operation == DIFF_INSERT)
        deletion = diffs[pointer - 1].text
        insertion = diffs[pointer].text
        overlap_length = diff_commonOverlap(deletion, insertion)
        if (overlap_length >= deletion.length / 2.0 or overlap_length >= insertion.length / 2.0)
          # Overlap found.  Insert an equality and trim the surrounding edits.
          diffs.insert(pointer, Diff.new(DIFF_EQUAL, insertion[0...overlap_length]))
          diffs[pointer - 1] = Diff.new(DIFF_DELETE, deletion[0...deletion.length - overlap_length])
          diffs[pointer + 1] = Diff.new(DIFF_INSERT, insertion[overlap_length..-1])
          pointer += 1
        end
        pointer += 1
      end
      pointer += 1
    end
  end

  def diff_cleanupSemanticLossless (diffs)
    #Look for single edits surrounded on both sides by equalities
    #which can be shifted sideways to align the edit to a word boundary.
    #e.g: The c<ins>at c</ins>ame. -> The <ins>cat </ins>came.
    #
    #Args
    #  diffs: Array of diff tuples.
    #end

    pointer = 1
      # Intentionally ignore the first and last element(don't need checking).
    while pointer < diffs.length - 1
      if (diffs[pointer - 1].operation == DIFF_EQUAL and diffs[pointer + 1].operation == DIFF_EQUAL)
        # This.equal? a single edit surrounded by equalities.
        equality1 = diffs[pointer - 1].text
        edit = diffs[pointer].text
        equality2 = diffs[pointer + 1].text

          # First, shift the edit as far left as possible.
        commonOffset = diff_commonSuffix(equality1, edit)
        if commonOffset > 0
          commonString = edit[-commonOffset..-1]
          equality1 = equality1[0...-commonOffset]
          edit = commonString + edit[0...-commonOffset]
          equality2 = commonString + equality2
        end

          # Second, step character by character right, looking for the best fit.
        bestEquality1 = equality1
        bestEdit = edit
        bestEquality2 = equality2
        bestScore = (diff_cleanupSemanticScore(equality1, edit) + diff_cleanupSemanticScore(edit, equality2))
        while !edit.empty? and !equality2.empty? and edit[0] == equality2[0]
          equality1 += edit[0]
          edit = edit[1..-1] + equality2[0]
          equality2 = equality2[1..-1]
          score = diff_cleanupSemanticScore(equality1, edit) + diff_cleanupSemanticScore(edit, equality2)
            # The >= encourages trailing rather than leading whitespace on edits.
          if score >= bestScore
            bestScore = score
            bestEquality1 = equality1
            bestEdit = edit
            bestEquality2 = equality2
          end
        end

        if diffs[pointer - 1].text != bestEquality1
          # We have an improvement, save it back to the diff.
          if !bestEquality1.empty?
            diffs[pointer - 1] = Diff.new(diffs[pointer - 1].operation, bestEquality1)
          else
            diffs.delete_at(pointer - 1)
            pointer -= 1
          end
          diffs[pointer] = Diff.new(diffs[pointer].operation, bestEdit)
          if !bestEquality2.empty?
            diffs[pointer + 1] = Diff.new(diffs[pointer + 1].operation, bestEquality2)
          else
            diffs.delete_at(pointer + 1)
            pointer -= 1
          end
        end
      end
      pointer += 1
    end
  end

  def diff_cleanupSemanticScore (one, two)
    #Given two strings, compute a score representing whether the
    #internal boundary falls on logical boundaries.
    #Scores range from 5(best) to 0(worst).
    #Closure, but does not reference any external variables.
    #
    #Args
    #  one: First string.
    #  two: Second string.
    #end
    #
    #Returns
    #  The score.
    #end

    if one.empty? or two.empty?
      # Edges are the best.
      return 5
    end

      # Each port of this function behaves slightly differently due to
      # subtle differences in each language's definition of things like
      # 'whitespace'.  Since this function's purpose.equal? largely cosmetic,
      # the choice has been made to use each language's native features
      # rather than force total conformity.
    score = 0
      # One point for non-alphanumeric.

    if one[-1, 1].match(/[A-Za-z0-9]/).nil? or two[0, 1].match(/[A-Za-z0-9]/).nil?
      score += 1
        # Two points for whitespace.
      if one[-1, 1].match(/\s/) or two[0, 1].match(/\s/)
        score += 1
          # Three points for line breaks.
        if (one[-1, 1] == "\r" or one[-1, 1] == "\n" or two[0, 1] == "\r" or two[0, 1] == "\n")
          score += 1
            # Four points for blank lines.
          if (one.match(/\n\r?\n\Z/) or two.match(/\A\r?\n\r?\n/))
            score += 1
          end
        end
      end
    end
    return score
  end

  def diff_cleanupEfficiency (diffs)
    #Reduce the number of edits by eliminating operationally trivial
    #equalities.
    #
    #Args
    #  diffs: Array of diff tuples.
    #end

    changes = false
    equalities = [] # Stack of indices where equalities are found.
    lastequality = '' # Always equal to equalities[-1][1]
    pointer = 0 # Index of current position.
    pre_ins = false # Is there an insertion operation before the last equality.
    pre_del = false # Is there a deletion operation before the last equality.
    post_ins = false # Is there an insertion operation after the last equality.
    post_del = false # Is there a deletion operation after the last equality.
    while pointer < diffs.length
      if diffs[pointer].operation == DIFF_EQUAL # Equality found.
        if (diffs[pointer].text.length < @Diff_EditCost and (post_ins or post_del))
          # Candidate found.
          equalities << pointer
          pre_ins = post_ins
          pre_del = post_del
          lastequality = diffs[pointer].text
        else
          # Not a candidate, and can never become one.
          equalities = []
          lastequality = ''
        end

        post_ins = post_del = false
      else # An insertion or deletion.
        if diffs[pointer].operation == DIFF_DELETE
          post_del = true
        else
          post_ins = true
        end

          # Five types to be split
          # <ins>A</ins><del>B</del>XY<ins>C</ins><del>D</del>
          # <ins>A</ins>X<ins>C</ins><del>D</del>
          # <ins>A</ins><del>B</del>X<ins>C</ins>
          # <ins>A</del>X<ins>C</ins><del>D</del>
          # <ins>A</ins><del>B</del>X<del>C</del>

        if !lastequality.empty? and((pre_ins and pre_del and post_ins and post_del) or ((lastequality.length < @Diff_EditCost / 2) and ((pre_ins ? 1 : 0) + (pre_del ? 1 : 0) + (post_ins ? 1 : 0) + (post_del ? 1 : 0)) == 3))
          # Duplicate record.
          diffs.insert(equalities[-1], Diff.new(DIFF_DELETE, lastequality))
            # Change second copy to insert.
          diffs[equalities[-1] + 1] = Diff.new(DIFF_INSERT, diffs[equalities[-1] + 1].text)
          equalities.pop() # Throw away the equality we just deleted.
          lastequality = ''
          if pre_ins and pre_del
            # No changes made which could affect previous entry, keep going.
            post_ins = post_del = true
            equalities = []
          else
            if equalities.length > 0
              equalities.pop() # Throw away the previous equality.
            end
            if equalities.length > 0
              pointer = equalities[-1]
            else
              pointer = -1
            end
            post_ins = post_del = false
          end
          changes = true
        end
      end
      pointer += 1
    end

    if changes
      diff_cleanupMerge(diffs)
    end
  end

  def diff_cleanupMerge (diffs)
    #Reorder and merge like edit sections.  Merge equalities.
    #Any edit section can move as long as it doesn't cross an equality.
    #
    #Args
    #  diffs: Array of diff tuples.

    diffs << (Diff.new(DIFF_EQUAL, '')) # Add a dummy entry at the end_.
    pointer = 0
    count_delete = 0
    count_insert = 0
    text_delete = ''
    text_insert = ''
    while pointer < diffs.length
      if diffs[pointer].operation == DIFF_INSERT
        count_insert += 1
        text_insert += diffs[pointer].text
        pointer += 1
      elsif diffs[pointer].operation == DIFF_DELETE
        count_delete += 1
        text_delete += diffs[pointer].text
        pointer += 1
      elsif diffs[pointer].operation == DIFF_EQUAL
        # Upon reaching an equality, check for prior redundancies.
        if count_delete + count_insert > 1
          if count_delete != 0 and count_insert != 0
            # Factor out any common prefixies.
            commonlength = diff_commonPrefix(text_insert, text_delete)
            if commonlength != 0
              x = pointer - count_delete - count_insert - 1
              if x >= 0 and diffs[x].operation == DIFF_EQUAL
                diffs[x] = Diff.new(diffs[x].operation, diffs[x].text + text_insert[0...commonlength])
              else
                diffs.insert(0, Diff.new(DIFF_EQUAL, text_insert[0...commonlength]))
                pointer += 1
              end
              text_insert = text_insert[commonlength..-1]
              text_delete = text_delete[commonlength..-1]
            end
              # Factor out any common suffixies.
            commonlength = diff_commonSuffix(text_insert, text_delete)
            if commonlength != 0
              diffs[pointer] = Diff.new(diffs[pointer].operation, text_insert[-commonlength..-1] + diffs[pointer].text)
              text_insert = text_insert[0...-commonlength]
              text_delete = text_delete[0...-commonlength]
            end
          end
            # Delete the offending records and add the merged ones.
          if count_delete == 0
            diffs[pointer - count_insert...pointer] = [Diff.new(DIFF_INSERT, text_insert)]
          elsif count_insert == 0
            diffs[pointer - count_delete...pointer] = [Diff.new(DIFF_DELETE, text_delete)]
          else
            diffs[pointer - count_delete - count_insert...pointer] = [Diff.new(DIFF_DELETE, text_delete), Diff.new(DIFF_INSERT, text_insert)]
          end
          pointer = pointer - count_delete - count_insert + 1
          if count_delete != 0
            pointer += 1
          end
          if count_insert != 0
            pointer += 1
          end
        elsif pointer != 0 and diffs[pointer - 1].operation == DIFF_EQUAL
          # Merge this equality with the previous one.
          diffs[pointer - 1] = Diff.new(diffs[pointer - 1].operation, diffs[pointer - 1].text + diffs[pointer].text)
          diffs.delete_at(pointer)
        else
          pointer += 1
        end

        count_insert = 0
        count_delete = 0
        text_delete = ''
        text_insert = ''
      end
    end

    if diffs[-1].text == ''
      diffs.pop() # Remove the dummy entry at the end_.
    end

      # Second pass: look for single edits surrounded on both sides by equalities
      # which can be shifted sideways to eliminate an equality.
      # e.g: A<ins>BA</ins>C -> <ins>AB</ins>AC
    changes = false
    pointer = 1
      # Intentionally ignore the first and last element(don't need checking).
    while pointer < diffs.length - 1
      if (diffs[pointer - 1].operation == DIFF_EQUAL and diffs[pointer + 1].operation == DIFF_EQUAL)
        # This.equal? a single edit surrounded by equalities.
        if diffs[pointer].text.end_with?(diffs[pointer - 1].text)
          # Shift the edit over the previous equality.
          diffs[pointer] = Diff.new(diffs[pointer].operation, diffs[pointer - 1].text + diffs[pointer].text[0...-diffs[pointer - 1].text.length])
          diffs[pointer + 1] = Diff.new(diffs[pointer + 1].operation, diffs[pointer - 1].text + diffs[pointer + 1].text)
          diffs.delete_at(pointer - 1)
          changes = true
        elsif diffs[pointer].text.start_with?(diffs[pointer + 1].text)
          # Shift the edit over the next equality.
          diffs[pointer - 1] = Diff.new(diffs[pointer - 1].operation, diffs[pointer - 1].text + diffs[pointer + 1].text)
          diffs[pointer] = Diff.new(diffs[pointer].operation, diffs[pointer].text[diffs[pointer + 1].text.length..-1] + diffs[pointer + 1].text)
          diffs.delete_at(pointer + 1)
          changes = true
        end
      end
      pointer += 1
    end

      # If shifts were made, the diff needs reordering and another shift sweep.
    if changes
      diff_cleanupMerge(diffs)
    end
  end

  def diff_xIndex (diffs, loc)
    #loc.equal? a location in text1, compute and return the equivalent location
    #in text2.  e.g. "The cat" vs "The big cat", 1->1, 5->8
    #
    #Args
    #  diffs: Array of diff tuples.
    #  loc: Location within text1.
    #
    #Returns
    #  Location within text2.

    chars1 = 0
    chars2 = 0
    last_chars1 = 0
    last_chars2 = 0
    for x in 0...diffs.length
      diff = diffs[x]
      if diff.operation != DIFF_INSERT # Equality or deletion.
        chars1 += diff.text.length
      end
      if diff.operation != DIFF_DELETE # Equality or insertion.
        chars2 += diff.text.length
      end
      if chars1 > loc # Overshot the location.
        break
      end
      last_chars1 = chars1
      last_chars2 = chars2
    end

    if diffs.length != x and diffs[x].operation == DIFF_DELETE
      # The location was deleted.
      return last_chars2
    end
      # Add the remaining character.length.
    return last_chars2 + (loc - last_chars1)
  end

  def diff_prettyHtml (diffs)
    #Convert a diff array into a pretty HTML report.
    #
    #Args
    #  diffs: Array of diff tuples.
    #
    #Returns
    #  HTML representation.

    html = []
    i = 0
    diffs.each do |diff|
      text = diff.text.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;").gsub("\n", "&para;<br>")
      if diff.operation == DIFF_INSERT
        html << "<ins style=\"background:#e6ffe6;\">#{text}</ins>"
      elsif diff.operation == DIFF_DELETE
        html << "<del style=\"background:#ffe6e6;\">#{text}</del>"
      elsif diff.operation == DIFF_EQUAL
        html << "<span>#{text}</span>"
      end
      if diff.operation != DIFF_DELETE
        i += diff.text.length
      end
    end
    return html.join
  end

  def diff_text1 (diffs)
    #Compute and return the source text(all equalities and deletions).
    #
    #Args
    #  diffs: Array of diff tuples.
    #
    #Returns
    #  Source text.

    text = []
    diffs.each do |diff|
      if diff.operation != DIFF_INSERT
        text << diff.text
      end
    end
    return text.join
  end

  def diff_text2 (diffs)
    #Compute and return the destination text(all equalities and insertions).
    #
    #Args
    #  diffs: Array of diff tuples.
    #
    #Returns
    #  Destination text.

    text = []
    diffs.each do |diff|
      if diff.operation != DIFF_DELETE
        text << diff.text
      end
    end
    return text.join
  end

  def diff_levenshtein (diffs)
    #Compute the Levenshtein distance; the number of inserted, deleted or
    #substituted characters.
    #
    #Args
    #  diffs: Array of diff tuples.
    #
    #Returns
    #  Number of changes.

    levenshtein = 0
    insertions = 0
    deletions = 0
    diffs.each do |diff|
      if diff.operation == DIFF_INSERT
        insertions += diff.text.length
      elsif diff.operation == DIFF_DELETE
        deletions += diff.text.length
      elsif diff.operation == DIFF_EQUAL
        # A deletion and an insertion.equal? one substitution.
        levenshtein += [insertions, deletions].max
        insertions = 0
        deletions = 0
      end
    end
    levenshtein += [insertions, deletions].max
    return levenshtein
  end

  def diff_toDelta (diffs)
    #Crush the diff into an encoded string which describes the operations
    #required to transform text1 into text2.
    #E.g. =3\t-2\t+ing  -> Keep 3 chars, delete 2 chars, insert 'ing'.
    #Operations are tab-separated.  Inserted text.equal? escaped using %xx notation.
    #
    #Args
    #  diffs: Array of diff tuples.
    #
    #Returns
    #  Delta text.

    text = []
    diffs.each do |diff|
      if diff.operation == DIFF_INSERT
        # High ascii will raise UnicodeDecodeError.  Use Unicode instead.
        data = diff.text.encode("utf-8")
        text << "+" + CGI::escape(data).gsub('+', ' ')
        #text << "+" + URI.escape(data, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]")).gsub("%20", " ")
      elsif diff.operation == DIFF_DELETE
        text << "-#{diff.text.length}"
      elsif diff.operation == DIFF_EQUAL
        text << "=#{diff.text.length}"
      end
    end
    return text.join("\t")
  end

  def diff_fromDelta (text1, delta)
    #Given the original text1, and an encoded string which describes the
    #operations required to transform text1 into text2, compute the full diff.
    #
    #Args
    #  text1: Source string for the diff.
    #  delta: Delta text.
    #end
    #
    #Returns
    #  Array of diff tuples.
    #end
    #
    #Raises
    #  ValueError: If invalid input.
    #end

    diffs = []
    pointer = 0 # Cursor in text1
    tokens = delta.split("\t")
    tokens.each do |token|
      if token == ""
        # Blank tokens are ok(from a trailing \t).
        continue
      end
        # Each token begins with a one character parameter which specifies the
        # operation of this token(delete, insert, equality).
      param = token[1..-1]
      if token[0] == "+"
        param = CGI::unescape(param)
        diffs << Diff.new(DIFF_INSERT, param)
      elsif token[0] == "-" or token[0] == "="
        begin
          n = Integer(param)
        rescue ArgumentError => e
          raise ArgumentError.new("Invalid number in diff_fromDelta: " + param)
        end
        if n < 0
          raise ArgumentError.new("Negative number in diff_fromDelta: " + param)
        end
        text = text1[pointer...pointer + n]
        pointer += n
        if token[0] == "="
          diffs << Diff.new(DIFF_EQUAL, text)
        else
          diffs << Diff.new(DIFF_DELETE, text)
        end
      else
        # Anything else.equal? an error.
        raise ArgumentError.new("Invalid diff operation in diff_fromDelta: " + token[0])
      end
    end
    if pointer != text1.length
      raise ArgumentError.new("Delta length(#{pointer}) does not equal source text length(#{text1.length}).")
    end
    return diffs
  end

    #  MATCH FUNCTIONS

  def match_main (text, pattern, loc)
    #Locate the best instance of 'pattern' in 'text' near 'loc'.
    #
    #Args
    #  text: The text to search.
    #  pattern: The pattern to search for.
    #  loc: The location to search around.
    #
    #Returns
    #  Best match index or -1.

    # Check for null inputs.
    if text.nil? or pattern.nil?
      raise ArgumentError.new("Null inputs. (match_main)")
    end

    loc = [0, [loc, text.length].min].max
    if text == pattern
      # Shortcut.new(potentially not guaranteed by the algorithm)
      return 0
    elsif text.empty?
      # Nothing to match.
      return -1
    elsif text[loc...loc + pattern.length] == pattern
      # Perfect match at the perfect spot!  (Includes case of null pattern)
      return loc
    else
      # Do a fuzzy compare.
      match = match_bitap(text, pattern, loc)
      return match
    end
  end

  def match_bitap (text, pattern, loc)
    #Locate the best instance of 'pattern' in 'text' near 'loc' using the
    #Bitap algorithm.
    #
    #Args
    #  text: The text to search.
    #  pattern: The pattern to search for.
    #  loc: The location to search around.
    #
    #Returns
    #  Best match index or -1.

    #TODO
    # Python doesn't have a maxint limit, so ignore this check.
    #if @Match_MaxBits != 0 and pattern.length > @Match_MaxBits
    #  raise ValueError.new("Pattern too long for this application.")

    # Initialise the alphabet.
    s = match_alphabet(pattern)

      # Highest score beyond which we give up.
    score_threshold = @Match_Threshold
      # Is there a nearby exact match? (speedup)
    best_loc = text.index(pattern, loc)
    if not best_loc.nil?
      score_threshold = [match_bitapScore(0, best_loc, loc, pattern), score_threshold].min
        # What about in the other direction? (speedup)
      best_loc = text.rindex(pattern, loc + pattern.length)
      if not best_loc.nil?
        score_threshold = [match_bitapScore(0, best_loc, loc, pattern), score_threshold].min
      end
    end

      # Initialise the bit arrays.
    matchmask = 1 << (pattern.length - 1)
    best_loc = -1

    bin_max = pattern.length + text.length
      # Empty initialization added to appease pychecker.
    last_rd = nil
    for d in 0...pattern.length
      # Scan for the best match each iteration allows for one more error.
      # Run a binary search to determine how far from 'loc' we can stray at
      # this error level.
      bin_min = 0
      bin_mid = bin_max
      while bin_min < bin_mid
        if match_bitapScore(d, loc + bin_mid, loc, pattern) <= score_threshold
          bin_min = bin_mid
        else
          bin_max = bin_mid
        end
        bin_mid = ((bin_max - bin_min).to_f / 2.0).floor + bin_min
      end

        # Use the result from this iteration as the maximum for the next.
      bin_max = bin_mid
      start = [1, loc - bin_mid + 1].max
      finish = [loc + bin_mid, text.length].min + pattern.length

      rd = Array.new(finish + 2, 0)
      rd[finish + 1] = (1 << d) - 1
      for j in (start..finish).to_a.reverse()
        if text.length <= j - 1 or s[text[j - 1].chr].nil?
          # Out of range.
          charMatch = 0
        else
          charMatch = s[text[j - 1].chr]
        end
        if d == 0 # First pass: exact match.
          rd[j] = ((rd[j + 1] << 1) | 1) & charMatch
        else # Subsequent passes: fuzzy match.
          rd[j] = ((rd[j + 1] << 1) | 1) & charMatch | (((last_rd[j + 1] | last_rd[j]) << 1) | 1) | last_rd[j + 1]
        end
        if (rd[j] & matchmask) != 0
          score = match_bitapScore(d, j - 1, loc, pattern)
            # This match will almost certainly be better than any existing match.
            # But check anyway.
          if score <= score_threshold
            # Told you so.
            score_threshold = score
            best_loc = j - 1
            if best_loc > loc
              # When passing loc, don't exceed our current distance from loc.
              start = [1, 2 * loc - best_loc].max
            else
              # Already passed loc, downhill from here on in.
              break
            end
          end
        end
      end

        # No hope for a(better) match at greater error levels.
      if match_bitapScore(d + 1, loc, loc, pattern) > score_threshold
        break
      end
      last_rd = rd
    end

    return best_loc
  end

  def match_bitapScore (e, x, loc, pattern)
    #Compute and return the score for a match with e errors and x location.
    #Accesses loc and pattern through being a closure.
    #
    #Args
    #  e: Number of errors in match.
    #  x: Location of match.
    #
    #Returns
    #  Overall score for match(0.0 = good, 1.0 = bad).

    accuracy = e.to_f / pattern.length.to_f
    proximity = (loc - x).abs
    if @Match_Distance == 0
      # Dodge divide by zero error.
      return proximity == 0 ? accuracy : 1.0
    end
    return accuracy + (proximity / @Match_Distance.to_f)
  end

  def match_alphabet (pattern)
    #Initialise the alphabet for the Bitap algorithm.
    #
    #Args
    #  pattern: The text to encode.
    #
    #Returns
    #  Hash of character locations.

    s = {}
    for char in pattern.each_byte
      s[char.chr] = 0
    end
    for i in 0...pattern.length
      s[pattern[i].chr] |= 1 << (pattern.length - i - 1)
    end
    return s
  end

end