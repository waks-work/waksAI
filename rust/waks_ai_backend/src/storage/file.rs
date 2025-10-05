use std::path::PathBuf;
use tokio::fs;

const STORAGE_DIR: &str = "storage_data";

pub async fn save(key: &str, value: &str) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    let path = PathBuf::from(STORAGE_DIR).join(key);
    fs::create_dir_all(STORAGE_DIR).await?;
    fs::write(path, value).await?;
    Ok(())
}

pub async fn load(key: &str) -> Result<Option<String>, Box<dyn std::error::Error + Send + Sync>> {
    let path = PathBuf::from(STORAGE_DIR).join(key);
    if path.exists() {
        let content = fs::read_to_string(path).await?;
        Ok(Some(content))
    } else {
        Ok(None)
    }
}

pub async fn delete(key: &str) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    let path = PathBuf::from(STORAGE_DIR).join(key);
    if path.exists() {
        fs::remove_file(path).await?;
    }
    Ok(())
}
