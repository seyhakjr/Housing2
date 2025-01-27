import torch
import pandas as pd
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import MinMaxScaler
import joblib

# Define the neural network model
class PricePredictorNN(torch.nn.Module):
    def __init__(self):
        super(PricePredictorNN, self).__init__()
        self.layer1 = torch.nn.Linear(5, 64)  # Input layer (5 features) to hidden layer (64 neurons)
        self.layer2 = torch.nn.Linear(64, 32)  # Hidden layer (32 neurons)
        self.layer3 = torch.nn.Linear(32, 16)  # Hidden layer (16 neurons)
        self.output = torch.nn.Linear(16, 1)  # Output layer (1 neuron for regression)
        self.relu = torch.nn.ReLU()  # Activation function

    def forward(self, x):
        x = self.relu(self.layer1(x))
        x = self.relu(self.layer2(x))
        x = self.relu(self.layer3(x))
        x = self.output(x)
        return x

# Load and preprocess the data
def load_and_preprocess_data():
    # Load the dataset
    data = pd.read_csv("kc_house_data.csv")  # Replace with your dataset path
    features = ["sqft_living", "grade", "yr_built", "sqft_lot", "condition"]  # Additional features
    target = "price"

    # Extract features and target
    X = data[features]
    y = data[target]

    # Remove outliers (e.g., prices above a certain threshold)
    y = y[y < 2_000_000]  # Adjust the threshold as needed
    X = X.loc[y.index]

    # Normalize the data
    scaler_X = MinMaxScaler()
    scaler_y = MinMaxScaler()

    X_scaled = scaler_X.fit_transform(X)
    y_scaled = scaler_y.fit_transform(y.values.reshape(-1, 1))

    return X_scaled, y_scaled, scaler_X, scaler_y, X, y

# Train the model
def train_model(X_train, y_train, epochs=100, batch_size=32):
    model = PricePredictorNN()
    criterion = torch.nn.MSELoss()  # Mean Squared Error Loss
    optimizer = torch.optim.Adam(model.parameters(), lr=0.001)  # Adam optimizer

    # Convert data to PyTorch tensors
    X_train_tensor = torch.tensor(X_train, dtype=torch.float32)
    y_train_tensor = torch.tensor(y_train, dtype=torch.float32)

    # Training loop
    for epoch in range(epochs):
        optimizer.zero_grad()
        outputs = model(X_train_tensor)
        loss = criterion(outputs, y_train_tensor)
        loss.backward()
        optimizer.step()

        if (epoch + 1) % 10 == 0:
            print(f"Epoch [{epoch+1}/{epochs}], Loss: {loss.item():.4f}")

    return model

# Save the model and scalers
def save_model_and_scalers(model, scaler_X, scaler_y):
    torch.save(model.state_dict(), "price_predictor_nn.pth")
    joblib.dump(scaler_X, "scaler_X.pkl")
    joblib.dump(scaler_y, "scaler_y.pkl")

# Main function to train and save the model
if __name__ == "__main__":
    # Load and preprocess data
    X_scaled, y_scaled, scaler_X, scaler_y, X, y = load_and_preprocess_data()

    # Print data ranges for debugging
    print("Original X range:", X.min().values, X.max().values)
    print("Original y range:", y.min(), y.max())
    print("Scaled X range:", X_scaled.min(), X_scaled.max())
    print("Scaled y range:", y_scaled.min(), y_scaled.max())

    # Split data into training and testing sets
    X_train, X_test, y_train, y_test = train_test_split(X_scaled, y_scaled, test_size=0.2, random_state=42)

    # Train the model
    model = train_model(X_train, y_train)

    # Save the model and scalers
    save_model_and_scalers(model, scaler_X, scaler_y)
    print("Model and scalers saved successfully.")