from urllib.parse import parse_qs
from channels.db import database_sync_to_async
from channels.middleware import BaseMiddleware
from django.contrib.auth.models import AnonymousUser
from django.contrib.auth import get_user_model
from rest_framework_simplejwt.tokens import AccessToken
from rest_framework_simplejwt.exceptions import TokenError

User = get_user_model()


@database_sync_to_async
def get_user(token_str):
    try:
        token   = AccessToken(token_str)
        user_id = token.get("user_id")
        return User.objects.get(id=user_id, is_active=True)
    except Exception:
        return AnonymousUser()


class JWTAuthMiddleware(BaseMiddleware):
    async def __call__(self, scope, receive, send):
        qs     = parse_qs(scope.get("query_string", b"").decode())
        tokens = qs.get("token", [])

        if not tokens:
            headers = dict(scope.get("headers", []))
            auth    = headers.get(b"authorization", b"").decode()
            if auth.startswith("Bearer "):
                tokens = [auth[7:]]

        scope["user"] = await get_user(tokens[0]) if tokens else AnonymousUser()
        return await super().__call__(scope, receive, send)


def JWTAuthMiddlewareStack(inner):
    return JWTAuthMiddleware(inner)
