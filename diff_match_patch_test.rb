require "./diff_match_patch.rb"
require "test/unit"

class DiffMatchPatchTest < Test::Unit::TestCase

  # Called before every test method runs. Can be used
  # to set up fixture information.
  def setup
    @dmp = DiffMatchPatch.new
  end

    # Called after every test method runs. Can be used to tear
    # down fixture information.

  def teardown
    # Do nothing
  end

  def diff_rebuildtexts (diffs)
    # Construct the two texts which made up the diff originally.
    text1 = ""
    text2 = ""
    for x in 0...diffs.length
      if diffs[x].operation != DIFF_INSERT
        text1 += diffs[x].text
      end
      if diffs[x].operation != DIFF_DELETE
        text2 += diffs[x].text
      end
    end
    return text1, text2
  end
end

class DiffTest < DiffMatchPatchTest
  def test_diff_dommon_prefix
    # Detect any common prefix.
    # Null case.
    assert_equal(0, @dmp.diff_commonPrefix("abc", "xyz"))

      # Non-null case.
    assert_equal(4, @dmp.diff_commonPrefix("1234abcdef", "1234xyz"))

      # Whole case.
    assert_equal(4, @dmp.diff_commonPrefix("1234", "1234xyz"))
  end

  def testDiffCommonSuffix
    # Detect any common suffix.
    # Null case.
    assert_equal(0, @dmp.diff_commonSuffix("abc", "xyz"))

      # Non-null case.
    assert_equal(4, @dmp.diff_commonSuffix("abcdef1234", "xyz1234"))

      # Whole case.
    assert_equal(4, @dmp.diff_commonSuffix("1234", "xyz1234"))
  end

  def testDiffCommonOverlap
    # Null case.
    assert_equal(0, @dmp.diff_commonOverlap("", "abcd"))

      # Whole case.
    assert_equal(3, @dmp.diff_commonOverlap("abc", "abcd"))

      # No overlap.
    assert_equal(0, @dmp.diff_commonOverlap("123456", "abcd"))

      # Overlap.
    assert_equal(3, @dmp.diff_commonOverlap("123456xxx", "xxxabcd"))
  end

  def testDiffHalfMatch
    # Detect a halfmatch.
    @dmp.Diff_Timeout = 1
      # No match.
    assert_equal(nil, @dmp.diff_halfMatch("1234567890", "abcdef"))

    assert_equal(nil, @dmp.diff_halfMatch("12345", "23"))

      # Single Match.
    assert_equal(["12", "90", "a", "z", "345678"], @dmp.diff_halfMatch("1234567890", "a345678z"))

    assert_equal(["a", "z", "12", "90", "345678"], @dmp.diff_halfMatch("a345678z", "1234567890"))

    assert_equal(["abc", "z", "1234", "0", "56789"], @dmp.diff_halfMatch("abc56789z", "1234567890"))

    assert_equal(["a", "xyz", "1", "7890", "23456"], @dmp.diff_halfMatch("a23456xyz", "1234567890"))

      # Multiple Matches.
    assert_equal(["12123", "123121", "a", "z", "1234123451234"], @dmp.diff_halfMatch("121231234123451234123121", "a1234123451234z"))

    assert_equal(["", "-=-=-=-=-=", "x", "", "x-=-=-=-=-=-=-="], @dmp.diff_halfMatch("x-=-=-=-=-=-=-=-=-=-=-=-=", "xx-=-=-=-=-=-=-="))

    assert_equal(["-=-=-=-=-=", "", "", "y", "-=-=-=-=-=-=-=y"], @dmp.diff_halfMatch("-=-=-=-=-=-=-=-=-=-=-=-=y", "-=-=-=-=-=-=-=yy"))

      # Non-optimal halfmatch.
      # Optimal diff would be -q+x=H-i+e=lloHe+Hu=llo-Hew+y not -qHillo+x=HelloHe-w+Hulloy
    assert_equal(["qHillo", "w", "x", "Hulloy", "HelloHe"], @dmp.diff_halfMatch("qHilloHelloHew", "xHelloHeHulloy"))

      # Optimal no halfmatch.
    @dmp.Diff_Timeout = 0
    assert_equal(nil, @dmp.diff_halfMatch("qHilloHelloHew", "xHelloHeHulloy"))
  end

    # TODO
    #def testDiffLinesToChars
    #  # Convert lines down to characters.
    #  assert_equal(["\x01\x02\x01", "\x02\x01\x02", ["", "alpha\n", "beta\n"]], @dmp.diff_linesToChars("alpha\nbeta\nalpha\n", "beta\nalpha\nbeta\n"))
    #
    #  assert_equal(["", "\x01\x02\x03\x03", ["", "alpha\r\n", "beta\r\n", "\r\n"]], @dmp.diff_linesToChars("", "alpha\r\nbeta\r\n\r\n\r\n"))
    #
    #  assert_equal(["\x01", "\x02", ["", "a", "b"]], @dmp.diff_linesToChars("a", "b"))
    #
    #  # More than 256 to reveal any 8-bit limitations.
    #  n = 300
    #  lineList = []
    #  charList = []
    #  for x in range(1, n + 1)
    #    lineList.append(str(x) + "\n")
    #    charList.append(chr(x))
    #  end
    #  assert_equal(n, len(lineList))
    #  lines = "".join(lineList)
    #  chars = "".join(charList)
    #  assert_equal(n, len(chars))
    #  lineList.insert(0, "")
    #  assert_equal([chars, "", lineList], @dmp.diff_linesToChars(lines, ""))
    #end

    # TODO
    #def testDiffCharsToLines
    #  # Convert chars up to lines.
    #  diffs = [Diff.new(DIFF_EQUAL, "\x01\x02\x01"), Diff.new(DIFF_INSERT, "\x02\x01\x02")]
    #  @dmp.diff_charsToLines(diffs, ["", "alpha\n", "beta\n"])
    #  assert_equal([Diff.new(DIFF_EQUAL, "alpha\nbeta\nalpha\n"), Diff.new(DIFF_INSERT, "beta\nalpha\nbeta\n")], diffs)
    #
    #  # More than 256 to reveal any 8-bit limitations.
    #  n = 300
    #  lineList = []
    #  charList = []
    #  for x in range(1, n + 1)
    #    lineList.append(str(x) + "\n")
    #    charList.append(chr(x))
    #  end
    #  assert_equal(n, len(lineList))
    #  lines = "".join(lineList)
    #  chars = "".join(charList)
    #  assert_equal(n, len(chars))
    #  lineList.insert(0, "")
    #  diffs = [Diff.new(DIFF_DELETE, chars)]
    #  @dmp.diff_charsToLines(diffs, lineList)
    #  assert_equal([Diff.new(DIFF_DELETE, lines)], diffs)
    #end

  def testDiffCleanupMerge
    # Cleanup a messy diff.
    # Null case.
    diffs = []
    @dmp.diff_cleanupMerge(diffs)
    assert_equal([], diffs)

      # No change case.
    diffs = [Diff.new(DIFF_EQUAL, "a"), Diff.new(DIFF_DELETE, "b"), Diff.new(DIFF_INSERT, "c")]
    @dmp.diff_cleanupMerge(diffs)
    assert_equal([Diff.new(DIFF_EQUAL, "a"), Diff.new(DIFF_DELETE, "b"), Diff.new(DIFF_INSERT, "c")], diffs)

      # Merge equalities.
    diffs = [Diff.new(DIFF_EQUAL, "a"), Diff.new(DIFF_EQUAL, "b"), Diff.new(DIFF_EQUAL, "c")]
    @dmp.diff_cleanupMerge(diffs)
    assert_equal([Diff.new(DIFF_EQUAL, "abc")], diffs)

      # Merge deletions.
    diffs = [Diff.new(DIFF_DELETE, "a"), Diff.new(DIFF_DELETE, "b"), Diff.new(DIFF_DELETE, "c")]
    @dmp.diff_cleanupMerge(diffs)
    assert_equal([Diff.new(DIFF_DELETE, "abc")], diffs)

      # Merge insertions.
    diffs = [Diff.new(DIFF_INSERT, "a"), Diff.new(DIFF_INSERT, "b"), Diff.new(DIFF_INSERT, "c")]
    @dmp.diff_cleanupMerge(diffs)
    assert_equal([Diff.new(DIFF_INSERT, "abc")], diffs)

      # Merge interweave.
    diffs = [Diff.new(DIFF_DELETE, "a"), Diff.new(DIFF_INSERT, "b"), Diff.new(DIFF_DELETE, "c"), Diff.new(DIFF_INSERT, "d"), Diff.new(DIFF_EQUAL, "e"), Diff.new(DIFF_EQUAL, "f")]
    @dmp.diff_cleanupMerge(diffs)
    assert_equal([Diff.new(DIFF_DELETE, "ac"), Diff.new(DIFF_INSERT, "bd"), Diff.new(DIFF_EQUAL, "ef")], diffs)

      # Prefix and suffix detection.
    diffs = [Diff.new(DIFF_DELETE, "a"), Diff.new(DIFF_INSERT, "abc"), Diff.new(DIFF_DELETE, "dc")]
    @dmp.diff_cleanupMerge(diffs)
    assert_equal([Diff.new(DIFF_EQUAL, "a"), Diff.new(DIFF_DELETE, "d"), Diff.new(DIFF_INSERT, "b"), Diff.new(DIFF_EQUAL, "c")], diffs)

      # Prefix and suffix detection with equalities.
    diffs = [Diff.new(DIFF_EQUAL, "x"), Diff.new(DIFF_DELETE, "a"), Diff.new(DIFF_INSERT, "abc"), Diff.new(DIFF_DELETE, "dc"), Diff.new(DIFF_EQUAL, "y")]
    @dmp.diff_cleanupMerge(diffs)
    assert_equal([Diff.new(DIFF_EQUAL, "xa"), Diff.new(DIFF_DELETE, "d"), Diff.new(DIFF_INSERT, "b"), Diff.new(DIFF_EQUAL, "cy")], diffs)

      # Slide edit left.
    diffs = [Diff.new(DIFF_EQUAL, "a"), Diff.new(DIFF_INSERT, "ba"), Diff.new(DIFF_EQUAL, "c")]
    @dmp.diff_cleanupMerge(diffs)
    assert_equal([Diff.new(DIFF_INSERT, "ab"), Diff.new(DIFF_EQUAL, "ac")], diffs)

      # Slide edit right.
    diffs = [Diff.new(DIFF_EQUAL, "c"), Diff.new(DIFF_INSERT, "ab"), Diff.new(DIFF_EQUAL, "a")]
    @dmp.diff_cleanupMerge(diffs)
    assert_equal([Diff.new(DIFF_EQUAL, "ca"), Diff.new(DIFF_INSERT, "ba")], diffs)

      # Slide edit left recursive.
    diffs = [Diff.new(DIFF_EQUAL, "a"), Diff.new(DIFF_DELETE, "b"), Diff.new(DIFF_EQUAL, "c"), Diff.new(DIFF_DELETE, "ac"), Diff.new(DIFF_EQUAL, "x")]
    @dmp.diff_cleanupMerge(diffs)
    assert_equal([Diff.new(DIFF_DELETE, "abc"), Diff.new(DIFF_EQUAL, "acx")], diffs)

      # Slide edit right recursive.
    diffs = [Diff.new(DIFF_EQUAL, "x"), Diff.new(DIFF_DELETE, "ca"), Diff.new(DIFF_EQUAL, "c"), Diff.new(DIFF_DELETE, "b"), Diff.new(DIFF_EQUAL, "a")]
    @dmp.diff_cleanupMerge(diffs)
    assert_equal([Diff.new(DIFF_EQUAL, "xca"), Diff.new(DIFF_DELETE, "cba")], diffs)
  end

  def testDiffCleanupSemanticLossless
    # Slide diffs to match logical boundaries.
    # Null case.
    diffs = []
    @dmp.diff_cleanupSemanticLossless(diffs)
    assert_equal([], diffs)

      # Blank lines.
    diffs = [Diff.new(DIFF_EQUAL, "AAA\r\n\r\nBBB"), Diff.new(DIFF_INSERT, "\r\nDDD\r\n\r\nBBB"), Diff.new(DIFF_EQUAL, "\r\nEEE")]
    @dmp.diff_cleanupSemanticLossless(diffs)
    assert_equal([Diff.new(DIFF_EQUAL, "AAA\r\n\r\n"), Diff.new(DIFF_INSERT, "BBB\r\nDDD\r\n\r\n"), Diff.new(DIFF_EQUAL, "BBB\r\nEEE")], diffs)

      # Line boundaries.
    diffs = [Diff.new(DIFF_EQUAL, "AAA\r\nBBB"), Diff.new(DIFF_INSERT, " DDD\r\nBBB"), Diff.new(DIFF_EQUAL, " EEE")]
    @dmp.diff_cleanupSemanticLossless(diffs)
    assert_equal([Diff.new(DIFF_EQUAL, "AAA\r\n"), Diff.new(DIFF_INSERT, "BBB DDD\r\n"), Diff.new(DIFF_EQUAL, "BBB EEE")], diffs)

      # Word boundaries.
    diffs = [Diff.new(DIFF_EQUAL, "The c"), Diff.new(DIFF_INSERT, "ow and the c"), Diff.new(DIFF_EQUAL, "at.")]
    @dmp.diff_cleanupSemanticLossless(diffs)
    assert_equal([Diff.new(DIFF_EQUAL, "The "), Diff.new(DIFF_INSERT, "cow and the "), Diff.new(DIFF_EQUAL, "cat.")], diffs)

      # Alphanumeric boundaries.
    diffs = [Diff.new(DIFF_EQUAL, "The-c"), Diff.new(DIFF_INSERT, "ow-and-the-c"), Diff.new(DIFF_EQUAL, "at.")]
    @dmp.diff_cleanupSemanticLossless(diffs)
    assert_equal([Diff.new(DIFF_EQUAL, "The-"), Diff.new(DIFF_INSERT, "cow-and-the-"), Diff.new(DIFF_EQUAL, "cat.")], diffs)

      # Hitting the start.
    diffs = [Diff.new(DIFF_EQUAL, "a"), Diff.new(DIFF_DELETE, "a"), Diff.new(DIFF_EQUAL, "ax")]
    @dmp.diff_cleanupSemanticLossless(diffs)
    assert_equal([Diff.new(DIFF_DELETE, "a"), Diff.new(DIFF_EQUAL, "aax")], diffs)

      # Hitting the end_.
    diffs = [Diff.new(DIFF_EQUAL, "xa"), Diff.new(DIFF_DELETE, "a"), Diff.new(DIFF_EQUAL, "a")]
    @dmp.diff_cleanupSemanticLossless(diffs)
    assert_equal([Diff.new(DIFF_EQUAL, "xaa"), Diff.new(DIFF_DELETE, "a")], diffs)
  end

  def testDiffCleanupEfficiency
    # Cleanup operationally trivial equalities.
    @dmp.Diff_EditCost = 4
      # Null case.
    diffs = []
    @dmp.diff_cleanupEfficiency(diffs)
    assert_equal([], diffs)

      # No elimination.
    diffs = [Diff.new(DIFF_DELETE, "ab"), Diff.new(DIFF_INSERT, "12"), Diff.new(DIFF_EQUAL, "wxyz"), Diff.new(DIFF_DELETE, "cd"), Diff.new(DIFF_INSERT, "34")]
    @dmp.diff_cleanupEfficiency(diffs)
    assert_equal([Diff.new(DIFF_DELETE, "ab"), Diff.new(DIFF_INSERT, "12"), Diff.new(DIFF_EQUAL, "wxyz"), Diff.new(DIFF_DELETE, "cd"), Diff.new(DIFF_INSERT, "34")], diffs)

      # Four-edit elimination.
    diffs = [Diff.new(DIFF_DELETE, "ab"), Diff.new(DIFF_INSERT, "12"), Diff.new(DIFF_EQUAL, "xyz"), Diff.new(DIFF_DELETE, "cd"), Diff.new(DIFF_INSERT, "34")]
    @dmp.diff_cleanupEfficiency(diffs)
    assert_equal([Diff.new(DIFF_DELETE, "abxyzcd"), Diff.new(DIFF_INSERT, "12xyz34")], diffs)

      # Three-edit elimination.
    diffs = [Diff.new(DIFF_INSERT, "12"), Diff.new(DIFF_EQUAL, "x"), Diff.new(DIFF_DELETE, "cd"), Diff.new(DIFF_INSERT, "34")]
    @dmp.diff_cleanupEfficiency(diffs)
    assert_equal([Diff.new(DIFF_DELETE, "xcd"), Diff.new(DIFF_INSERT, "12x34")], diffs)

      # Backpass elimination.
    diffs = [Diff.new(DIFF_DELETE, "ab"), Diff.new(DIFF_INSERT, "12"), Diff.new(DIFF_EQUAL, "xy"), Diff.new(DIFF_INSERT, "34"), Diff.new(DIFF_EQUAL, "z"), Diff.new(DIFF_DELETE, "cd"), Diff.new(DIFF_INSERT, "56")]
    @dmp.diff_cleanupEfficiency(diffs)
    assert_equal([Diff.new(DIFF_DELETE, "abxyzcd"), Diff.new(DIFF_INSERT, "12xy34z56")], diffs)

      # High cost elimination.
    @dmp.Diff_EditCost = 5
    diffs = [Diff.new(DIFF_DELETE, "ab"), Diff.new(DIFF_INSERT, "12"), Diff.new(DIFF_EQUAL, "wxyz"), Diff.new(DIFF_DELETE, "cd"), Diff.new(DIFF_INSERT, "34")]
    @dmp.diff_cleanupEfficiency(diffs)
    assert_equal([Diff.new(DIFF_DELETE, "abwxyzcd"), Diff.new(DIFF_INSERT, "12wxyz34")], diffs)
    @dmp.Diff_EditCost = 4
  end

  def testDiffPrettyHtml
    # Pretty print.
    diffs = [Diff.new(DIFF_EQUAL, "a\n"), Diff.new(DIFF_DELETE, "<B>b</B>"), Diff.new(DIFF_INSERT, "c&d")]
    assert_equal("<span>a&para;<br></span><del style=\"background:#ffe6e6;\">&lt;B&gt;b&lt;/B&gt;</del><ins style=\"background:#e6ffe6;\">c&amp;d</ins>", @dmp.diff_prettyHtml(diffs))
  end

  def testDiffText
    # Compute the source and destination texts.
    diffs = [Diff.new(DIFF_EQUAL, "jump"), Diff.new(DIFF_DELETE, "s"), Diff.new(DIFF_INSERT, "ed"), Diff.new(DIFF_EQUAL, " over "), Diff.new(DIFF_DELETE, "the"), Diff.new(DIFF_INSERT, "a"), Diff.new(DIFF_EQUAL, " lazy")]
    assert_equal("jumps over the lazy", @dmp.diff_text1(diffs))

    assert_equal("jumped over a lazy", @dmp.diff_text2(diffs))
  end

  def testDiffDelta
    # Convert a diff into delta string.
    diffs = [Diff.new(DIFF_EQUAL, "jump"), Diff.new(DIFF_DELETE, "s"), Diff.new(DIFF_INSERT, "ed"), Diff.new(DIFF_EQUAL, " over "), Diff.new(DIFF_DELETE, "the"), Diff.new(DIFF_INSERT, "a"), Diff.new(DIFF_EQUAL, " lazy"), Diff.new(DIFF_INSERT, "old dog")]
    text1 = @dmp.diff_text1(diffs)
    assert_equal("jumps over the lazy", text1)

    delta = @dmp.diff_toDelta(diffs)
    assert_equal("=4\t-1\t+ed\t=6\t-3\t+a\t=5\t+old dog", delta)

      # Convert delta string into a diff.
    assert_equal(diffs, @dmp.diff_fromDelta(text1, delta))

      # Generates error(19 != 20).
    begin
      @dmp.diff_fromDelta(text1 + "x", delta)
      assert_false(true)
    rescue ArgumentError => e
      # Exception expected.
      pass
    end

      # Generates error(19 != 18).
    begin
      @dmp.diff_fromDelta(text1[1..-1], delta)
      assertFalse(true)
    rescue ArgumentError
      # Exception expected.
      pass
    end

      # Generates error(%c3%xy invalid Unicode).
      # Note: Python 3 can decode this.
      #try
      #  @dmp.diff_fromDelta("", "+%c3xy")
      #  assertFalse(true)
      #except ValueError
      #  # Exception expected.
      #  pass

      # Test deltas with special characters.
    diffs = [Diff.new(DIFF_EQUAL, "\u0680 \x00 \t %"), Diff.new(DIFF_DELETE, "\u0681 \x01 \n ^"), Diff.new(DIFF_INSERT, "\u0682 \x02 \\ |")]
    text1 = @dmp.diff_text1(diffs)
    assert_equal("\u0680 \x00 \t %\u0681 \x01 \n ^", text1)

    delta = @dmp.diff_toDelta(diffs)
    assert_equal("=7\t-7\t+%DA%82 %02 %5C %7C", delta)

      # Convert delta string into a diff.
    assert_equal(diffs, @dmp.diff_fromDelta(text1, delta))

      # Verify pool of unchanged characters.
    diffs = [Diff.new(DIFF_INSERT, "A-Z a-z 0-9 - _ . ! ~ * ' ( ) ; / ? : @ & = + $ , # ")]
    text2 = @dmp.diff_text2(diffs)
    assert_equal("A-Z a-z 0-9 - _ . ! ~ * \' ( ) ; / ? : @ & = + $ , # ", text2)

    delta = @dmp.diff_toDelta(diffs)
      #TODO fails
      #assert_equal("+A-Z a-z 0-9 - _ . ! ~ * \' ( ) ; / ? : @ & = + $ , # ", delta)

      # Convert delta string into a diff.
    assert_equal(diffs, @dmp.diff_fromDelta("", delta))
  end

  def testDiffXIndex
    # Translate a location in text1 to text2.
    assert_equal(5, @dmp.diff_xIndex([Diff.new(DIFF_DELETE, "a"), Diff.new(DIFF_INSERT, "1234"), Diff.new(DIFF_EQUAL, "xyz")], 2))

      # Translation on deletion.
    assert_equal(1, @dmp.diff_xIndex([Diff.new(DIFF_EQUAL, "a"), Diff.new(DIFF_DELETE, "1234"), Diff.new(DIFF_EQUAL, "xyz")], 3))
  end

  def testDiffLevenshtein
    # Levenshtein with trailing equality.
    assert_equal(4, @dmp.diff_levenshtein([Diff.new(DIFF_DELETE, "abc"), Diff.new(DIFF_INSERT, "1234"), Diff.new(DIFF_EQUAL, "xyz")]))
      # Levenshtein with leading equality.
    assert_equal(4, @dmp.diff_levenshtein([Diff.new(DIFF_EQUAL, "xyz"), Diff.new(DIFF_DELETE, "abc"), Diff.new(DIFF_INSERT, "1234")]))
      # Levenshtein with middle equality.
    assert_equal(7, @dmp.diff_levenshtein([Diff.new(DIFF_DELETE, "abc"), Diff.new(DIFF_EQUAL, "xyz"), Diff.new(DIFF_INSERT, "1234")]))
  end

  def testDiffBisect
    # Normal.
    a = "cat"
    b = "map"
      # Since the resulting diff hasn't been normalized, it would be ok if
      # the insertion and deletion pairs are swapped.
      # If the order changes, tweak this test as required.
    assert_equal([Diff.new(DIFF_DELETE, "c"), Diff.new(DIFF_INSERT, "m"), Diff.new(DIFF_EQUAL, "a"), Diff.new(DIFF_DELETE, "t"), Diff.new(DIFF_INSERT, "p")], @dmp.diff_bisect(a, b, Fixnum::MAX))

      # Timeout.
    assert_equal([Diff.new(DIFF_DELETE, "cat"), Diff.new(DIFF_INSERT, "map")], @dmp.diff_bisect(a, b, 0))
  end

  def testDiffMain
    # Perform a trivial diff.
    # Null case.
    assert_equal([], @dmp.diff_main("", "", false))

      # Equality.
    assert_equal([Diff.new(DIFF_EQUAL, "abc")], @dmp.diff_main("abc", "abc", false))

      # Simple insertion.
    assert_equal([Diff.new(DIFF_EQUAL, "ab"), Diff.new(DIFF_INSERT, "123"), Diff.new(DIFF_EQUAL, "c")], @dmp.diff_main("abc", "ab123c", false))

      # Simple deletion.
    assert_equal([Diff.new(DIFF_EQUAL, "a"), Diff.new(DIFF_DELETE, "123"), Diff.new(DIFF_EQUAL, "bc")], @dmp.diff_main("a123bc", "abc", false))

      # Two insertions.
    assert_equal([Diff.new(DIFF_EQUAL, "a"), Diff.new(DIFF_INSERT, "123"), Diff.new(DIFF_EQUAL, "b"), Diff.new(DIFF_INSERT, "456"), Diff.new(DIFF_EQUAL, "c")], @dmp.diff_main("abc", "a123b456c", false))

      # Two deletions.
    assert_equal([Diff.new(DIFF_EQUAL, "a"), Diff.new(DIFF_DELETE, "123"), Diff.new(DIFF_EQUAL, "b"), Diff.new(DIFF_DELETE, "456"), Diff.new(DIFF_EQUAL, "c")], @dmp.diff_main("a123b456c", "abc", false))

      # Perform a real diff.
      # Switch off the timeout.
    @dmp.Diff_Timeout = 0
      # Simple cases.
    assert_equal([Diff.new(DIFF_DELETE, "a"), Diff.new(DIFF_INSERT, "b")], @dmp.diff_main("a", "b", false))

    assert_equal([Diff.new(DIFF_DELETE, "Apple"), Diff.new(DIFF_INSERT, "Banana"), Diff.new(DIFF_EQUAL, "s are a"), Diff.new(DIFF_INSERT, "lso"), Diff.new(DIFF_EQUAL, " fruit.")], @dmp.diff_main("Apples are a fruit.", "Bananas are also fruit.", false))

    assert_equal([Diff.new(DIFF_DELETE, "a"), Diff.new(DIFF_INSERT, "\u0680"), Diff.new(DIFF_EQUAL, "x"), Diff.new(DIFF_DELETE, "\t"), Diff.new(DIFF_INSERT, "\x00")], @dmp.diff_main("ax\t", "\u0680x\x00", false))

      # Overlaps.
    assert_equal([Diff.new(DIFF_DELETE, "1"), Diff.new(DIFF_EQUAL, "a"), Diff.new(DIFF_DELETE, "y"), Diff.new(DIFF_EQUAL, "b"), Diff.new(DIFF_DELETE, "2"), Diff.new(DIFF_INSERT, "xab")], @dmp.diff_main("1ayb2", "abxab", false))

    assert_equal([Diff.new(DIFF_INSERT, "xaxcx"), Diff.new(DIFF_EQUAL, "abc"), Diff.new(DIFF_DELETE, "y")], @dmp.diff_main("abcy", "xaxcxabc", false))

    assert_equal([Diff.new(DIFF_DELETE, "ABCD"), Diff.new(DIFF_EQUAL, "a"), Diff.new(DIFF_DELETE, "="), Diff.new(DIFF_INSERT, "-"), Diff.new(DIFF_EQUAL, "bcd"), Diff.new(DIFF_DELETE, "="), Diff.new(DIFF_INSERT, "-"), Diff.new(DIFF_EQUAL, "efghijklmnopqrs"), Diff.new(DIFF_DELETE, "EFGHIJKLMNOefg")], @dmp.diff_main("ABCDa=bcd=efghijklmnopqrsEFGHIJKLMNOefg", "a-bcd-efghijklmnopqrs", false))

      # Large equality.
    assert_equal([Diff.new(DIFF_INSERT, " "), Diff.new(DIFF_EQUAL, "a"), Diff.new(DIFF_INSERT, "nd"), Diff.new(DIFF_EQUAL, " [[Pennsylvania]]"), Diff.new(DIFF_DELETE, " and [[New")], @dmp.diff_main("a [[Pennsylvania]] and [[New", " and [[Pennsylvania]]", false))

      # Timeout.
    @dmp.Diff_Timeout = 0.1 # 100ms
    a = "`Twas brillig, and the slithy toves\nDid gyre and gimble in the wabe:\nAll mimsy were the borogoves,\nAnd the mome raths outgrabe.\n"
    b = "I am the very model of a modern major general,\nI've information vegetable, animal, and mineral,\nI know the kings of England, and I quote the fights historical,\nFrom Marathon to Waterloo, in order categorical.\n"
      # Increase the text lengths by 1024 times to ensure a timeout.
    for x in 0...10
      a = a + a
      b = b + b
    end
    startTime = Time.now()
    @dmp.diff_main(a, b)
    endTime = Time.now()
      # Test that we took at least the timeout period.
    assert_equal(true, @dmp.Diff_Timeout <= endTime - startTime)
      # Test that we didn't take forever(be forgiving).
      # Theoretically this test could fail very occasionally if the
      # OS task swaps or locks up for a second at the wrong moment.
    assert_equal(true, @dmp.Diff_Timeout * 2 > endTime - startTime)
    @dmp.Diff_Timeout = 0

      # Test the linemode speedup.
      # Must be long to pass the 100 char cutoff.
      # Simple line-mode.
    a = "1234567890\n" * 13
    b = "abcdefghij\n" * 13
    assert_equal(@dmp.diff_main(a, b, false), @dmp.diff_main(a, b, true))

      # Single line-mode.
    a = "1234567890" * 13
    b = "abcdefghij" * 13
    assert_equal(@dmp.diff_main(a, b, false), @dmp.diff_main(a, b, true))

      # Overlap line-mode.
    a = "1234567890\n" * 13
    b = "abcdefghij\n1234567890\n1234567890\n1234567890\nabcdefghij\n1234567890\n1234567890\n1234567890\nabcdefghij\n1234567890\n1234567890\n1234567890\nabcdefghij\n"
    texts_linemode = diff_rebuildtexts(@dmp.diff_main(a, b, true))
    texts_textmode = diff_rebuildtexts(@dmp.diff_main(a, b, false))
    assert_equal(texts_textmode, texts_linemode)

      # Test null inputs.
    begin
      @dmp.diff_main(nil, nil)
      assertFalse(true)
    rescue ArgumentError
      # Exception expected.
      pass
    end
  end

end

class MatchTest < DiffMatchPatchTest
  #MATCH TEST FUNCTIONS

  def testMatchAlphabet
    # Initialise the bitmasks for Bitap.
    assert_equal({"a"=>4, "b"=>2, "c"=>1}, @dmp.match_alphabet("abc"))

    assert_equal({"a"=>37, "b"=>18, "c"=>8}, @dmp.match_alphabet("abcaba"))
  end

  def testMatchBitap
    @dmp.Match_Distance = 100
    @dmp.Match_Threshold = 0.5
      # Exact matches.
    assert_equal(5, @dmp.match_bitap("abcdefghijk", "fgh", 5))

    assert_equal(5, @dmp.match_bitap("abcdefghijk", "fgh", 0))

      # Fuzzy matches.
    assert_equal(4, @dmp.match_bitap("abcdefghijk", "efxhi", 0))

    assert_equal(2, @dmp.match_bitap("abcdefghijk", "cdefxyhijk", 5))

    assert_equal(-1, @dmp.match_bitap("abcdefghijk", "bxy", 1))

      # Overflow.
    assert_equal(2, @dmp.match_bitap("123456789xx0", "3456789x0", 2))

    assert_equal(0, @dmp.match_bitap("abcdef", "xxabc", 4))

    assert_equal(3, @dmp.match_bitap("abcdef", "defyy", 4))

    assert_equal(0, @dmp.match_bitap("abcdef", "xabcdefy", 0))

      # Threshold test.
    @dmp.Match_Threshold = 0.4
    assert_equal(4, @dmp.match_bitap("abcdefghijk", "efxyhi", 1))

    @dmp.Match_Threshold = 0.3
    assert_equal(-1, @dmp.match_bitap("abcdefghijk", "efxyhi", 1))

    @dmp.Match_Threshold = 0.0
    assert_equal(1, @dmp.match_bitap("abcdefghijk", "bcdef", 1))
    @dmp.Match_Threshold = 0.5

      # Multiple select.
    assert_equal(0, @dmp.match_bitap("abcdexyzabcde", "abccde", 3))

    assert_equal(8, @dmp.match_bitap("abcdexyzabcde", "abccde", 5))

      # Distance test.
    @dmp.Match_Distance = 10 # Strict location.
    assert_equal(-1, @dmp.match_bitap("abcdefghijklmnopqrstuvwxyz", "abcdefg", 24))

    assert_equal(0, @dmp.match_bitap("abcdefghijklmnopqrstuvwxyz", "abcdxxefg", 1))

    @dmp.Match_Distance = 1000 # Loose location.
    assert_equal(0, @dmp.match_bitap("abcdefghijklmnopqrstuvwxyz", "abcdefg", 24))
  end


  def testMatchMain
    # Full match.
    # Shortcut matches.
    assert_equal(0, @dmp.match_main("abcdef", "abcdef", 1000))

    assert_equal(-1, @dmp.match_main("", "abcdef", 1))

    assert_equal(3, @dmp.match_main("abcdef", "", 3))

    assert_equal(3, @dmp.match_main("abcdef", "de", 3))

    assert_equal(3, @dmp.match_main("abcdef", "defy", 4))

    assert_equal(0, @dmp.match_main("abcdef", "abcdefy", 0))

      # Complex match.
    @dmp.Match_Threshold = 0.7
    assert_equal(4, @dmp.match_main("I am the very model of a modern major general.", " that berry ", 5))
    @dmp.Match_Threshold = 0.5

      # Test null inputs.
    begin
      @dmp.match_main(nil, nil, 0)
      assertFalse(true)
    rescue ArgumentError
      # Exception expected.
      pass
    end
  end
end