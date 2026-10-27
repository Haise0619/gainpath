package com.zyang.gainpath;

import java.io.FilterOutputStream;
import java.io.IOException;
import java.io.OutputStream;

/** Owns each native picker and guards every PDF output write against account drift. */
public final class WorkoutReportExportGuard {
    public static final class Token {
        public final int requestCode;
        private Token(int code) { requestCode = code; }
    }
    private int nextCode = 26000;
    private volatile Token current;
    public synchronized Token begin() {
        if (current != null || nextCode >= 60000) throw new IllegalStateException("Export unavailable");
        current = new Token(nextCode++);
        return current;
    }
    public synchronized boolean ownsCode(int code) { return code >= 26000 && code < nextCode; }
    public synchronized Token accept(int code) { return current != null && current.requestCode == code ? current : null; }
    public boolean isCurrent(Token token) { return token != null && current == token; }
    public synchronized void finish(Token token) { if (current == token) current = null; }
    public synchronized void cancel() { current = null; }
    public OutputStream guarded(Token token, OutputStream output) {
        return new FilterOutputStream(output) {
            private void check() throws IOException { if (!isCurrent(token)) throw new IOException("Export cancelled"); }
            @Override public void write(int value) throws IOException { check(); out.write(value); check(); }
            @Override public void write(byte[] bytes, int offset, int length) throws IOException {
                check(); out.write(bytes, offset, length); check();
            }
        };
    }
}
