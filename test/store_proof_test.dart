import 'package:flutter_test/flutter_test.dart';
import 'package:whats_that_mushroom/person/auth.dart';
import 'package:whats_that_mushroom/purchase/billing.dart';
import 'package:whats_that_mushroom/purchase/store_proof.dart';

void main() {
  tearDown(() {
    Auth.appUser = null;
    debugResetStoreProofHooks();
  });

  test('a receipt is sent only for the account that bought it', () {
    const ada = PendingStoreProof('ada', 'google_play', 'yearly', 'token-a');
    const bee = PendingStoreProof('bee', 'google_play', 'monthly', 'token-b');
    const signedOut = PendingStoreProof('', 'google_play', 'yearly', 'token-0');
    final mine = pendingProofsForAccount([ada, bee, signedOut], 'ada');
    expect(mine, [ada, signedOut]);
    expect(pendingProofsForAccount([ada], ''), isEmpty);
    expect(storeProofAppliesLocally('ada', 'ada'), isTrue);
    expect(storeProofAppliesLocally('ada', 'bee'), isFalse);
    expect(storeProofAppliesLocally('ada', null), isFalse);
  });

  test('a receipt saved without an account is not sent', () {
    final decoded = decodePendingProofs(
      '[{"store":"google_play","productId":"yearly","proof":"old"}]',
    );
    expect(decoded.proofs, isEmpty);
    expect(decoded.dropped, isTrue);
    final kept = decodePendingProofs(
      '[{"uid":"ada","store":"google_play","productId":"yearly","proof":"token"}]',
    );
    expect(kept.proofs, hasLength(1));
    expect(kept.proofs.single.uid, 'ada');
    expect(kept.dropped, isFalse);
  });

  test('register runs before Auth.publish sets the account', () async {
    Auth.appUser = null;
    debugStoreUid = () => 'ada';
    var called = false;
    debugRegisterStoreAccount = () async {
      called = true;
    };
    await registerStoreAccount();
    expect(called, isTrue);
  });

  test('a purchase check does not change the next account', () {
    expect(storePurchaseStillAccount('ada', 'ada'), isTrue);
    expect(storePurchaseStillAccount('ada', 'bee'), isFalse);
    expect(storePurchaseStillAccount('ada', null), isFalse);
    expect(storePurchaseStillAccount('', null), isTrue);
    expect(storePurchaseStillAccount('', 'bee'), isFalse);
  });

  test('a receipt owned by another account is a failed purchase', () {
    expect(
      storePurchaseNotesFailure(
        bought: true,
        result: StoreProofResult.rejected,
        responseLost: false,
      ),
      isTrue,
    );
    expect(
      storePurchaseNotesFailure(
        bought: true,
        result: StoreProofResult.deferred,
        responseLost: false,
      ),
      isFalse,
    );
    expect(
      storePurchaseNotesFailure(
        bought: true,
        result: StoreProofResult.rejected,
        responseLost: true,
      ),
      isFalse,
    );
  });
}
