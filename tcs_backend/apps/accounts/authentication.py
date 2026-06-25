# apps/accounts/authentication.py
#
# JWT authentication that also rejects suspended accounts on every request,
# so a moderation suspension cuts off live sessions immediately (not just at
# next login). Kept separate from is_active per the suspension design.

from rest_framework_simplejwt.authentication import JWTAuthentication
from rest_framework_simplejwt.exceptions import AuthenticationFailed


class SuspensionAwareJWTAuthentication(JWTAuthentication):
    def get_user(self, validated_token):
        user = super().get_user(validated_token)
        if getattr(user, "is_suspended", False):
            raise AuthenticationFailed("Account suspended", code="account_suspended")
        return user
