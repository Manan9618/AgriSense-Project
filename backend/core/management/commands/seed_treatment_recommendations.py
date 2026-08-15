import json

from django.conf import settings
from django.core.management.base import BaseCommand, CommandError

from core.constants import DISEASE_CLASS_IDS
from core.models import TreatmentRecommendation

CONTENT_PATH = settings.BASE_DIR.parent / "content" / "treatment_recommendations.json"


class Command(BaseCommand):
    help = "Load content/treatment_recommendations.json into TreatmentRecommendation rows."

    def handle(self, *args, **options):
        if not CONTENT_PATH.exists():
            raise CommandError(f"{CONTENT_PATH} not found")

        data = json.loads(CONTENT_PATH.read_text())
        classes = {k: v for k, v in data.items() if not k.startswith("_")}

        missing = set(DISEASE_CLASS_IDS) - set(classes)
        if missing:
            raise CommandError(f"Missing classes in {CONTENT_PATH}: {sorted(missing)}")

        created, updated = 0, 0
        for class_id, entry in classes.items():
            urgency = entry["urgency"]
            for language in ("en", "hi", "gu"):
                translation = entry[language]
                _, was_created = TreatmentRecommendation.objects.update_or_create(
                    class_id=class_id,
                    language=language,
                    defaults={
                        "title": translation["title"],
                        "instructions": translation["instructions"],
                        "urgency": urgency,
                    },
                )
                created += was_created
                updated += not was_created

        self.stdout.write(
            self.style.SUCCESS(
                f"Seeded {created + updated} rows "
                f"({created} created, {updated} updated) "
                f"across {len(classes)} classes."
            )
        )
