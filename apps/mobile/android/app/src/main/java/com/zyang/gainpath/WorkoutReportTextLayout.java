package com.zyang.gainpath;

import java.util.ArrayList;
import java.util.List;

/** Width-aware text layout; long identifiers are retained without ellipsis. */
public final class WorkoutReportTextLayout {
    public interface FittingCharacters { int count(String text); }
    private WorkoutReportTextLayout() {}

    public static List<String> wrap(String value, FittingCharacters fitting) {
        List<String> lines = new ArrayList<>();
        for (String paragraph : value.replace("\r\n", "\n").replace('\r', '\n').split("\n", -1)) {
            String remaining = paragraph;
            if (remaining.isEmpty()) lines.add("");
            while (!remaining.isEmpty()) {
                int count = Math.max(1, Math.min(remaining.length(), fitting.count(remaining)));
                if (count < remaining.length() && Character.isHighSurrogate(remaining.charAt(count - 1))) {
                    count = count == 1 ? Math.min(2, remaining.length()) : count - 1;
                }
                int end = count;
                if (count < remaining.length() && !Character.isWhitespace(remaining.charAt(count))) {
                    for (int i = count - 1; i > 0; i--) {
                        if (Character.isWhitespace(remaining.charAt(i))) { end = i; break; }
                    }
                }
                lines.add(remaining.substring(0, end));
                int next = end;
                while (next < remaining.length() && Character.isWhitespace(remaining.charAt(next))) next++;
                remaining = remaining.substring(next);
            }
        }
        return lines;
    }

    public static float blockHeight(int lines, float lineHeight, float pageHeight) {
        return Math.min(lines * lineHeight, pageHeight);
    }
}
