import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime

# Initialize Firebase (assuming local credentials or default auth)
# Since I'm on the user's system, I'll try to use the default credential or look for a service account if needed.
# Usually, in these environments, we can just use the project ID if auth is handled by the environment.

try:
    cred = credentials.ApplicationDefault()
    firebase_admin.initialize_app(cred, {
        'projectId': 'motodo-app',
    })
except Exception as e:
    print(f"Error initializing Firebase: {e}")
    # Fallback to just firestore.client() which might work if environment variables are set
    pass

db = firestore.client()

team_id = "fTe5XatMOx4zKoEa45T8"
other_user_uid = "RwZPX2vVV8UVzSv9kAspfe1Mox12"

tasks = [
    {
        "content": "Urgent Team Task (P1)",
        "priority": 1,
        "isSecret": False,
        "isCompleted": False,
        "createdBy": other_user_uid,
        "teamId": team_id,
        "createdAt": firestore.SERVER_TIMESTAMP
    },
    {
        "content": "Secret Team Task (P2)",
        "priority": 2,
        "isSecret": True,
        "isCompleted": False,
        "createdBy": other_user_uid,
        "teamId": team_id,
        "createdAt": firestore.SERVER_TIMESTAMP
    },
    {
        "content": "Regular Team Task (P3)",
        "priority": 3,
        "isSecret": False,
        "isCompleted": False,
        "createdBy": other_user_uid,
        "teamId": team_id,
        "createdAt": firestore.SERVER_TIMESTAMP
    }
]

for task in tasks:
    doc_ref = db.collection('todos').document()
    doc_ref.set(task)
    print(f"Created task: {task['content']} (ID: {doc_ref.id})")

print("Seeding completed.")
