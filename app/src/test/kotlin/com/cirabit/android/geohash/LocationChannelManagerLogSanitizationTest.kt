package com.cirabit.android.geohash

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Test

class LocationChannelManagerLogSanitizationTest {

    @Test
    fun sanitizeForSingleLineLog_replacesLineBreakCharacters() {
        val input = "Mesh\nAdmin\rTeam\u2028Area\u2029Room"

        val sanitized = sanitizeForSingleLineLog(input)

        assertEquals("Mesh Admin Team Area Room", sanitized)
        assertFalse(sanitized.contains('\n'))
        assertFalse(sanitized.contains('\r'))
        assertFalse(sanitized.contains('\u2028'))
        assertFalse(sanitized.contains('\u2029'))
    }

    @Test
    fun sanitizeForSingleLineLog_preservesSafeText() {
        val input = "Building - abc123"

        val sanitized = sanitizeForSingleLineLog(input)

        assertEquals(input, sanitized)
    }
}
