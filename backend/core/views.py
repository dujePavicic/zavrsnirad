from django.shortcuts import render

from django.http import JsonResponse

def status_view(request):
    
    return JsonResponse({
        'status': 'ok',
        'message': 'Backend je dostupan.'})
# Create your views here.
