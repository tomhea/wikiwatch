import Toybox.Lang;

// In-place text-buffer ops for the typing buffer. Pure module (only
// Toybox.Lang). Hebrew strings work because Monkey C String.length() returns
// char count (not bytes) and substring operates on char indices - verified
// in M1's storage round-trip test.
module InputBuffer {
    // Append a single character (or space) to the buffer.
    function append(buf as String, ch as String) as String {
        return buf + ch;
    }

    // Drop the last char from the buffer. No-op on empty (returns "").
    function popLast(buf as String) as String {
        var len = buf.length();
        if (len == 0) { return ""; }
        return buf.substring(0, len - 1);
    }

    // Return an empty buffer regardless of input.
    function clear(buf as String) as String {
        return "";
    }
}