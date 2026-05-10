from rest_framework import status
from rest_framework.decorators import api_view, parser_classes
from rest_framework.parsers import MultiPartParser, FormParser
from rest_framework.response import Response
from .validators import validate_file
from .models import MediaAsset


@api_view(["POST"])
@parser_classes([MultiPartParser, FormParser])
def upload_media(request):
    file = request.FILES.get("file")
    if not file:
        return Response({"error": "No file provided."}, status=400)
    try:
        validated = validate_file(file)
    except ValueError as e:
        return Response({"error": str(e)}, status=400)

    asset = MediaAsset.objects.create(
        uploaded_by=request.user,
        file=file,
        asset_type=validated["message_type"],
        mime_type=validated["mime"],
        file_size=file.size,
        original_name=file.name,
    )
    return Response({
        "id":         str(asset.id),
        "url":        request.build_absolute_uri(asset.file.url),
        "asset_type": asset.asset_type,
        "mime_type":  asset.mime_type,
        "file_size":  asset.file_size,
    }, status=status.HTTP_201_CREATED)


@api_view(["DELETE"])
def delete_media(request, asset_id):
    try:
        asset = MediaAsset.objects.get(id=asset_id, uploaded_by=request.user)
    except MediaAsset.DoesNotExist:
        return Response({"error": "Not found."}, status=404)
    asset.delete()
    return Response(status=status.HTTP_204_NO_CONTENT)
