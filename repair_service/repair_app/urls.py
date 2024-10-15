from django.urls import path
from repair_app import views

app_name = 'repair_app'

urlpatterns = [
    path('', views.index, name='index'),
    path('about', views.about, name='about'),
]