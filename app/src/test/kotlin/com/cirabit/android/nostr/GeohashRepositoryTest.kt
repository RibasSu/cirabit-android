package com.cirabit.android.nostr

import androidx.test.core.app.ApplicationProvider
import com.cirabit.android.ui.ChatState
import com.cirabit.android.ui.DataManager
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import java.util.Date

@RunWith(RobolectricTestRunner::class)
class GeohashRepositoryTest {

    @Test
    fun findPubkeyByShortId_returnsCachedNicknameMatch() {
        val repository = createRepository()
        repository.cacheNickname("aabbccddeeff00112233445566778899", "alice")

        val resolved = repository.findPubkeyByShortId("AABB")

        assertEquals("aabbccddeeff00112233445566778899", resolved)
    }

    @Test
    fun findPubkeyByShortId_fallsBackToParticipantMap() {
        val repository = createRepository()
        val pubkey = "deadbeef00112233445566778899aabb"
        repository.updateParticipant("u4pruy", pubkey, Date())

        val resolved = repository.findPubkeyByShortId("DEAD")

        assertEquals(pubkey, resolved)
    }

    @Test
    fun findPubkeyByShortId_returnsNullWhenUnknown() {
        val repository = createRepository()

        val resolved = repository.findPubkeyByShortId("1234")

        assertNull(resolved)
    }

    private fun createRepository(): GeohashRepository {
        val context = ApplicationProvider.getApplicationContext<android.content.Context>()
        val scope = CoroutineScope(SupervisorJob() + Dispatchers.Unconfined)
        val state = ChatState(scope)
        val dataManager = DataManager(context)
        return GeohashRepository(context.applicationContext as android.app.Application, state, dataManager)
    }
}
