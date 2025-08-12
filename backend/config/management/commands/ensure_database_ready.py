from django.core.management.base import BaseCommand
from django.core.management import call_command
from django.db import connection

class Command(BaseCommand):
    help = 'Ensure database is ready with migrations and data'

    def handle(self, *args, **options):
        self.stdout.write("🔧 Ensuring database is ready...")
        
        # Run migrations
        self.stdout.write("📦 Running migrations...")
        call_command('migrate', verbosity=0)
        
        # Check if we need to populate data
        self.stdout.write("🔍 Checking data state...")
        call_command('check_database')
        
        # Only populate if database is COMPLETELY empty (no auto-cleaning)
        from config.models import Zone, Table, Unit
        
        total_records = Zone.objects.count() + Table.objects.count() + Unit.objects.count()
        
        if total_records == 0:
            self.stdout.write("📊 Database is empty - populating initial data...")
            call_command('populate_production_data')
        else:
            self.stdout.write(f"✅ Database has data ({total_records} records) - skipping population")
            self.stdout.write("ℹ️  To manually reset database, run: python manage.py clean_database")
            
        self.stdout.write(
            self.style.SUCCESS("✅ Database is ready!")
        )