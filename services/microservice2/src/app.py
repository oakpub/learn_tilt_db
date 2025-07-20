from flask import Flask, jsonify
import psycopg2
import os
from datetime import datetime
import logging

app = Flask(__name__)
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Database configuration
DB_HOST = os.getenv('DB_HOST', 'postgres-service2')
DB_PORT = os.getenv('DB_PORT', '5432')
DB_NAME = os.getenv('DB_NAME', 'service2_db')
DB_USER = os.getenv('DB_USER', 'service2_user')
DB_PASSWORD = os.getenv('DB_PASSWORD', 'service2_password')

def get_db_connection():
    """Get database connection with error handling"""
    try:
        conn = psycopg2.connect(
            host=DB_HOST,
            port=DB_PORT,
            database=DB_NAME,
            user=DB_USER,
            password=DB_PASSWORD,
            connect_timeout=5
        )
        return conn
    except Exception as e:
        logger.error(f"Database connection failed: {e}")
        return None

@app.route('/health')
def health_check():
    """Health check endpoint"""
    try:
        conn = get_db_connection()
        if conn:
            conn.close()
            db_status = True
            message = "Service is healthy"
        else:
            db_status = False
            message = "Service is running but database is unavailable"
        
        return jsonify({
            'service': 'microservice2',
            'status': 'healthy' if db_status else 'degraded',
            'timestamp': datetime.now().isoformat(),
            'database_connected': db_status,
            'message': message
        }), 200 if db_status else 503
    except Exception as e:
        logger.error(f"Health check failed: {e}")
        return jsonify({
            'service': 'microservice2',
            'status': 'unhealthy',
            'timestamp': datetime.now().isoformat(),
            'database_connected': False,
            'message': f"Health check failed: {str(e)}"
        }), 500

@app.route('/db-status')
def database_status():
    """Database status endpoint"""
    try:
        conn = get_db_connection()
        if not conn:
            return jsonify({
                'service': 'microservice2',
                'database': {
                    'connected': False,
                    'error': 'Unable to connect to database',
                    'last_check': datetime.now().isoformat()
                }
            }), 503
        
        cursor = conn.cursor()
        
        # Get PostgreSQL version
        cursor.execute('SELECT version();')
        version = cursor.fetchone()[0]
        
        # Get table count
        cursor.execute("""
            SELECT COUNT(*) 
            FROM information_schema.tables 
            WHERE table_schema = 'public';
        """)
        table_count = cursor.fetchone()[0]
        
        # Create test table if it doesn't exist
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS service2_test (
                id SERIAL PRIMARY KEY,
                message TEXT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );
        """)
        
        # Insert test data
        cursor.execute("""
            INSERT INTO service2_test (message) 
            VALUES ('Test from microservice2 at ' || CURRENT_TIMESTAMP);
        """)
        
        # Get record count
        cursor.execute('SELECT COUNT(*) FROM service2_test;')
        record_count = cursor.fetchone()[0]
        
        conn.commit()
        cursor.close()
        conn.close()
        
        return jsonify({
            'service': 'microservice2',
            'database': {
                'connected': True,
                'version': version,
                'tables_count': table_count,
                'test_records': record_count,
                'last_check': datetime.now().isoformat()
            }
        }), 200
        
    except Exception as e:
        logger.error(f"Database status check failed: {e}")
        return jsonify({
            'service': 'microservice2',
            'database': {
                'connected': False,
                'error': str(e),
                'last_check': datetime.now().isoformat()
            }
        }), 500

@app.route('/api/service2')
def service2_api():
    """Service-specific API endpoint"""
    return jsonify({
        'service': 'microservice2',
        'message': 'Hello from Microservice 2!',
        'timestamp': datetime.now().isoformat(),
        'endpoints': ['/health', '/db-status', '/api/service2']
    })

@app.route('/')
def root():
    """Root endpoint"""
    return jsonify({
        'service': 'microservice2',
        'message': 'Microservice 2 is running',
        'available_endpoints': ['/health', '/db-status', '/api/service2']
    })

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5002, debug=True)