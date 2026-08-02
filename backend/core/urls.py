from django.urls import path
from rest_framework_simplejwt.views import TokenRefreshView

from . import views

urlpatterns = [
    path("registracija/", views.RegistracijaPogled.as_view(), name="registracija"),
    path("prijava/", views.PrijavaPogled.as_view(), name="prijava"),
    path("token/osvjezi/", TokenRefreshView.as_view(), name="osvjezi-token"),
    path("ja/", views.JaPogled.as_view(), name="ja"),
    path("odjava/", views.OdjavaPogled.as_view(), name="odjava"),
]