# apps/ai/router_views.py
#
# Diagnostic endpoint for the Phase 1 AI router. Staff-only. Shows which
# providers are configured and which lanes are live — so after you add an API
# key to the prod env you can hit this and watch the lane light up. Never
# returns key values, only whether each is present.

from rest_framework.decorators import api_view, permission_classes
from rest_framework.response import Response

from apps.accounts.permissions import IsStaff
from . import ai_router


@api_view(["GET"])
@permission_classes([IsStaff])
def ai_router_status(request):
    snap = ai_router.status()
    configured = [n for n, v in snap["providers"].items() if v["configured"]]
    return Response({
        "configured_providers": configured,
        "total_providers":      len(snap["providers"]),
        **snap,
    })
